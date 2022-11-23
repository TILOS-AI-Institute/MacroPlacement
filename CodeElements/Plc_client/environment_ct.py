# [We copy and modify the below code from https://github.com/google-research/circuit_training. This is only for testing purposes.]
# coding=utf-8
# Copyright 2021 The Circuit Training Team Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
"""Circuit training Environmnet with gin config."""

import datetime
import math
import os
from typing import Any, Callable, Dict, Text, Tuple, Optional

from absl import logging
from circuit_training.environment import coordinate_descent_placer as cd_placer
from circuit_training.environment import observation_config
from circuit_training.environment import observation_extractor
from circuit_training.environment import placement_util
from circuit_training.environment import plc_client
from circuit_training.environment import plc_client_os
import gin
import gym
import numpy as np
import random, sys
import tensorflow as tf
from tf_agents.environments import suite_gym
from tf_agents.environments import wrappers
# for slicing dict
import itertools

ObsType = Dict[Text, np.ndarray]
InfoType = Dict[Text, float]

DEBUG = False

# make save failed directory
if DEBUG:
  if not os.path.exists('failed_node_indices'):
    os.makedirs('failed_node_indices')
  if not os.path.exists('failed_proxy_plc'):
    os.makedirs('failed_proxy_plc')
  if not os.path.exists('failed_proxy_coord'):
    os.makedirs('failed_proxy_coord')
  if not os.path.exists('failed_obs'):
    os.makedirs('failed_obs')
  if not os.path.exists('failed_mask'):
    os.makedirs('failed_mask')

class InfeasibleActionError(ValueError):
  """An infeasible action were passed to the env."""

  def __init__(self, action, mask):
    """Initialize an infeasible action error.

    Args:
      action: Infeasible action that was performed.
      mask: The mask associated with the current observation. mask[action] is
        `0` for infeasible actions.
    """
    ValueError.__init__(self, action, mask)
    self.action = action
    self.mask = mask

  def __str__(self):
    return 'Infeasible action (%s) when the mask is (%s)' % (self.action,
                                                             self.mask)

@gin.configurable
def cost_info_function(
    plc: plc_client.PlacementCost,
    done: bool,
    wirelength_weight: float = 1.0,
    density_weight: float = 0.5,
    congestion_weight: float = 0.5) -> Tuple[float, Dict[Text, float]]:
  """Returns the RL cost and info.

  Args:
    plc: Placement cost object.
    done: Set if it is the terminal step.
    wirelength_weight:  Weight of wirelength in the reward function.
    density_weight: Weight of density in the reward function.
    congestion_weight: Weight of congestion in the reward function used only for
      legalizing the placement in greedy std cell placer.

  Returns:
    The RL cost.

  Raises:
    ValueError: When the cost mode is not supported.

  Notes: we found the default congestion and density weights more stable.
  """
  proxy_cost = 0.0

  if not done:
    return proxy_cost, {
        'wirelength': -1.0,
        'congestion': -1.0,
        'density': -1.0,
    }

  wirelength = -1.0
  congestion = -1.0
  density = -1.0

  if wirelength_weight > 0.0:
    wirelength = plc.get_cost()
    proxy_cost += wirelength_weight * wirelength

  if congestion_weight > 0.0:
    congestion = plc.get_congestion_cost()
    proxy_cost += congestion_weight * congestion

  if density_weight > 0.0:
    density = plc.get_density_cost()
    proxy_cost += density_weight * density

  info = {
      'wirelength': wirelength,
      'congestion': congestion,
      'density': density,
  }

  return proxy_cost, info

# OS
@gin.configurable
def cost_info_function_os(
    plc_os: plc_client_os.PlacementCost,
    done: bool,
    wirelength_weight: float = 1.0,
    density_weight: float = 0.5,
    congestion_weight: float = 0.5) -> Tuple[float, Dict[Text, float]]:
  """Returns the RL cost and info.

  Args:
    plc: Placement cost object.
    done: Set if it is the terminal step.
    wirelength_weight:  Weight of wirelength in the reward function.
    density_weight: Weight of density in the reward function.
    congestion_weight: Weight of congestion in the reward function used only for
      legalizing the placement in greedy std cell placer.

  Returns:
    The RL cost.

  Raises:
    ValueError: When the cost mode is not supported.

  Notes: we found the default congestion and density weights more stable.
  """
  proxy_cost = 0.0

  if not done:
    return proxy_cost, {
        'wirelength': -1.0,
        'congestion': -1.0,
        'density': -1.0,
    }

  wirelength = -1.0
  congestion = -1.0
  density = -1.0

  if wirelength_weight > 0.0:
    wirelength = plc_os.get_cost()
    proxy_cost += wirelength_weight * wirelength

  if congestion_weight > 0.0:
    congestion = plc_os.get_congestion_cost()
    proxy_cost += congestion_weight * congestion

  if density_weight > 0.0:
    density = plc_os.get_density_cost()
    proxy_cost += density_weight * density

  info = {
      'wirelength': wirelength,
      'congestion': congestion,
      'density': density,
  }

  return proxy_cost, info


@gin.configurable
class CircuitEnv(object):
  """Defines the CircuitEnv class."""

  INFEASIBLE_REWARD = -1.0

  def __init__(
      self,
      netlist_file: Text = '',
      init_placement: Text = '',
      create_placement_cost_fn: Callable[
          ..., plc_client.PlacementCost] = placement_util.create_placement_cost,
      std_cell_placer_mode: Text = 'fd',
      cost_info_fn: Callable[[plc_client.PlacementCost, bool],
                             Tuple[float, Dict[Text,
                                               float]]] = cost_info_function,
      global_seed: int = 0,
      is_eval: bool = False,
      save_best_cost: bool = False,
      output_plc_file: Text = '',
      make_soft_macros_square: bool = True,
      cd_finetune: bool = False,
      cd_plc_file: Text = 'ppo_cd_placement.plc',
      train_step: Optional[tf.Variable] = None,
      unplace_all_nodes_in_init: bool = True):
    """Creates a CircuitEnv.

    Args:
      netlist_file: Path to the input netlist file.
      init_placement: Path to the input inital placement file, used to read grid
        and canas size.
      create_placement_cost_fn: A function that given the netlist and initial
        placement file create the placement_cost object.
      std_cell_placer_mode: Options for fast std cells placement: `fd` (uses the
        force-directed algorithm).
      cost_info_fn: The cost function that given the plc object returns the RL
        cost.
      global_seed: Global seed for initializing env features. This seed should
        be the same across actors. Not used currently.
      is_eval: If set, save the final placement in output_dir.
      save_best_cost: Boolean, if set, saves the palcement if its cost is better
        than the previously saved palcement.
      output_plc_file: The path to save the final placement.
      make_soft_macros_square: If True, make the shape of soft macros square
        before using analytical std cell placers like FD.
      cd_finetune: If True, runs coordinate descent to finetune macro
        orientations. Supposed to run in eval only, not training.
      cd_plc_file: Name of the CD fine-tuned plc file, the file will be save in
        the same dir as output_plc_file
      train_step: A tf.Variable indicating the training step, only used for
        saving plc files in the evaluation.
      unplace_all_nodes_in_init: Unplace all nodes after initialization.
    """
    del global_seed
    if not netlist_file:
      raise ValueError('netlist_file must be provided.')

    self.netlist_file = netlist_file
    self._std_cell_placer_mode = std_cell_placer_mode
    self._cost_info_fn = cost_info_fn
    self._cost_info_fn_os = cost_info_function_os # OS
    self._is_eval = is_eval
    self._save_best_cost = save_best_cost
    self._output_plc_file = output_plc_file
    self._output_plc_dir = os.path.dirname(output_plc_file)
    self._make_soft_macros_square = make_soft_macros_square
    self._cd_finetune = cd_finetune
    self._cd_plc_file = cd_plc_file
    self._train_step = train_step

    self._plc = create_placement_cost_fn(
        netlist_file=netlist_file, init_placement=init_placement)
    
    # OS
    self._plc_os = placement_util.create_placement_cost_os(
         netlist_file=netlist_file, init_placement=init_placement)
    
    # OS
    self._hash = -1

    # We call ObservationExtractor before unplace_all_nodes, so we use the
    # inital placement in the static features (location_x and location_y).
    # This results in better placements.
    self._observation_config = observation_config.ObservationConfig()
    self._observation_extractor = observation_extractor.ObservationExtractor(
        plc=self._plc)
    # OS
    self._observation_extractor_os = observation_extractor.ObservationExtractor(
        plc=self._plc_os)

    if self._make_soft_macros_square:
      # It is better to make the shape of soft macros square before using
      # analytical std cell placers like FD.
      self._plc.make_soft_macros_square()

    self._grid_cols, self._grid_rows = self._plc.get_grid_num_columns_rows()
    self._canvas_width, self._canvas_height = self._plc.get_canvas_width_height(
    )

    # OS
    self._grid_cols, self._grid_rows = self._plc_os.get_grid_num_columns_rows()
    self._canvas_width, self._canvas_height = self._plc_os.get_canvas_width_height(
    )

    self._hard_macro_indices = [
        m for m in self._plc.get_macro_indices()
        if not self._plc.is_node_soft_macro(m)
    ]

    # OS
    self._hard_macro_indices_os = [
        m for m in self._plc_os.get_macro_indices()
        if not self._plc_os.is_node_soft_macro(m)
    ]

    if DEBUG and not (np.array(self._hard_macro_indices) == np.array(self._hard_macro_indices_os)).all():
        logging.info('*****DISCREPENCY FOUND IN HARD MACRO INDICES*****')
        with open('./failed_node_indices/hard_macro_indices_{}.npy'.format(str(self._hash)), 'wb') as f:
          # GL
          np.save(f, np.array(self._hard_macro_indices))
          # OS
          np.save(f, np.array(self._hard_macro_indices_os))
    else:
      logging.info('* hard macro indices matched *')

    self._num_hard_macros = len(self._hard_macro_indices_os)

    self._sorted_node_indices = placement_util.get_ordered_node_indices(
        mode='descending_size_macro_first', plc=self._plc)
    # OS
    self._sorted_node_indices_os = placement_util.get_ordered_node_indices(
        mode='descending_size_macro_first', plc=self._plc_os)

    if DEBUG and not (np.array(self._sorted_node_indices_os) == np.array(self._sorted_node_indices)).all():
        logging.info('*****DISCREPENCY FOUND IN NODE_INDICES*****')
        with open('./failed_node_indices/sorted_indices_{}.npy'.format(str(self._hash)), 'wb') as f:
          # GL
          np.save(f, np.array(self._sorted_node_indices))
          # OS
          np.save(f, np.array(self._sorted_node_indices_os))
    else:
      logging.info('* node indices matched *')

    self._sorted_soft_macros = self._sorted_node_indices_os[self._num_hard_macros:]

    # Generate a map from actual macro_index to its position in
    # self.macro_indices. Needed because node adjacency matrix is in the same
    # node order of plc.get_macro_indices.
    self._macro_index_to_pos = {}
    # for i, macro_index in enumerate(self._plc.get_macro_indices()):
    #   self._macro_index_to_pos[macro_index] = i
    # OS
    
    for i, (macro_index, macro_index_os) in enumerate(zip(self._plc.get_macro_indices(), self._plc_os.get_macro_indices())):
      if DEBUG and macro_index != macro_index_os:
        logging.info('*****DISCREPENCY FOUND IN MACRO_INDEX*****')
        with open('./failed_macro_index.txt', 'a+') as f:
          f.write("[hash:{}] at {}, gl: {}, os: {}".format(str(self._hash), str(i), str(macro_index), str(macro_index_os),'\n'))
      self._macro_index_to_pos[macro_index_os] = i

    # Padding for mapping the placement canvas on the agent canvas.
    rows_pad = self._observation_config.max_grid_size - self._grid_rows
    cols_pad = self._observation_config.max_grid_size - self._grid_cols
    self._up_pad = rows_pad // 2
    self._right_pad = cols_pad // 2
    self._low_pad = rows_pad - self._up_pad
    self._left_pad = cols_pad - self._right_pad

    self._saved_cost = np.inf
    self._current_actions = []
    self._current_node = 0
    self._done = False
    # OOM
    # self._current_mask = self._get_mask()
    # OS
    self._current_mask_os = self._get_mask_os()

    # Discrep Detection
    # if not (np.array(self._current_mask) == np.array(self._current_mask_os)).all():
    #   logging.info('*****DISCREPENCY FOUND IN CURRENT MASK*****')
    #   with open('./init_mask/run{}_node_{}.npy'.format(str(self._hash), str(self._current_node)), 'wb') as f:
    #     # GL
    #     np.save(f, np.array(self._current_mask))
    #     # OS
    #     np.save(f, np.array(self._current_mask_os))
    # else:
    #   logging.info('* node mask matched *')

    if unplace_all_nodes_in_init:
      # TODO(b/223026568) Remove unplace_all_nodes from init
      self._plc.unplace_all_nodes()
      # OS
      self._plc_os.unplace_all_nodes()
      logging.warning('* Unplaced all Nodes in init *')
    logging.info('***Num node to place***:%s', self._num_hard_macros)

  @property
  def observation_space(self) -> gym.spaces.Space:
    """Env Observation space."""
    return self._observation_config.observation_space

  @property
  def action_space(self) -> gym.spaces.Space:
    return gym.spaces.Discrete(self._observation_config.max_grid_size**2)

  @property
  def environment_name(self) -> Text:
    return self.netlist_file

  def get_static_obs(self):
    """Get the static observation for the environment.

    Static observations are invariant across steps on the same netlist, such as
    netlist metadata and the adj graphs. This should only be used for
    generalized RL.

    Returns:
      Numpy array representing the observation
    """
    return self._observation_extractor.get_static_features()

  # This is not used anywhere
  def get_cost_info(self,
                    done: bool = False) -> Tuple[float, Dict[Text, float]]:
    return self._cost_info_fn(plc=self._plc, done=done)  # pytype: disable=wrong-keyword-args  # trace-all-classes

  def _get_mask(self) -> np.ndarray:
    """Gets the node mask for the current node.

    Returns:
      List of 0s and 1s indicating if action is feasible or not.
    """
    if self._done:
      mask = np.zeros(self._observation_config.max_grid_size**2, dtype=np.int32)
    else:
      node_index = self._sorted_node_indices[self._current_node]
      mask = np.asarray(self._plc.get_node_mask(node_index), dtype=np.int32)
      mask = np.reshape(mask, [self._grid_rows, self._grid_cols])
      pad = ((self._up_pad, self._low_pad), (self._right_pad, self._left_pad))
      mask = np.pad(mask, pad, mode='constant', constant_values=0)
    return np.reshape(
        mask, (self._observation_config.max_grid_size**2,)).astype(np.int32)
  
  # OS
  def _get_mask_os(self) -> np.ndarray:
    """Gets the node mask for the current node.

    Returns:
      List of 0s and 1s indicating if action is feasible or not.
    """
    if self._done:
      mask = np.zeros(self._observation_config.max_grid_size**2, dtype=np.int32)
    else:
      node_index = self._sorted_node_indices_os[self._current_node]
      mask = np.asarray(self._plc_os.get_node_mask(node_index), dtype=np.int32)
      mask = np.reshape(mask, [self._grid_rows, self._grid_cols])
      pad = ((self._up_pad, self._low_pad), (self._right_pad, self._left_pad))
      mask = np.pad(mask, pad, mode='constant', constant_values=0)
    return np.reshape(
        mask, (self._observation_config.max_grid_size**2,)).astype(np.int32)

  def _get_obs(self) -> ObsType:
    """Returns the observation."""
    if self._current_node > 0:
      previous_node_sorted = self._sorted_node_indices[self._current_node - 1]
      previous_node_index = self._macro_index_to_pos[previous_node_sorted]
    else:
      previous_node_index = -1

    if self._current_node < self._num_hard_macros:
      current_node_sorted = self._sorted_node_indices[self._current_node]
      current_node_index = self._macro_index_to_pos[current_node_sorted]
    else:
      current_node_index = 0

    return self._observation_extractor.get_all_features(
        previous_node_index=previous_node_index,
        current_node_index=current_node_index,
        mask=self._current_mask)

  # OS
  def _get_obs_os(self) -> ObsType:
    """Returns the observation."""
    if self._current_node > 0:
      previous_node_sorted = self._sorted_node_indices_os[self._current_node - 1]
      previous_node_index = self._macro_index_to_pos[previous_node_sorted]
    else:
      previous_node_index = -1

    if self._current_node < self._num_hard_macros:
      current_node_sorted = self._sorted_node_indices_os[self._current_node]
      current_node_index = self._macro_index_to_pos[current_node_sorted]
    else:
      current_node_index = 0

    return self._observation_extractor_os.get_all_features(
        previous_node_index=previous_node_index,
        current_node_index=current_node_index,
        mask=self._current_mask_os)

  def _run_cd(self):
    """Runs coordinate descent to finetune the current placement."""

    # CD only modifies macro orientation.
    # Plc modified by CD will be reset at the end of the episode.

    def cost_fn(plc):
      return self._cost_info_fn(plc=plc, done=True)  # pytype: disable=wrong-keyword-args  # trace-all-classes

    cd = cd_placer.CoordinateDescentPlacer(
        plc=self._plc,
        cost_fn=cost_fn,
        use_stdcell_placer=True,
        optimize_only_orientation=True)
    cd.place()

  def _save_placement(self, cost: float) -> None:
    """Saves the current placement.

    Args:
      cost: the current placement cost.

    Raises:
      IOError: If we cannot write the placement to file.
    """
    if not self._save_best_cost or (cost < self._saved_cost and
                                    (math.fabs(cost - self._saved_cost) /
                                     (cost) > 5e-3)):
      user_comments = ''
      if self._train_step:
        user_comments = f'Train step : {self._train_step.numpy()}'

      placement_util.save_placement(self._plc, self._output_plc_file,
                                    user_comments)
      ts = datetime.datetime.now().strftime('%Y%m%d_%H%M%S')
      ppo_snapshot_file = os.path.join(
          self._output_plc_dir,
          f'snapshot_ppo_opt_placement_timestamp_{ts}_cost_{cost:.4f}.plc')
      placement_util.save_placement(self._plc, ppo_snapshot_file, user_comments)
      self._saved_cost = cost

      # Only runs CD if this is the best RL placement seen so far.
      if self._cd_finetune:
        self._run_cd()
        cost = self._cost_info_fn(plc=self._plc, done=True)[0]  # pytype: disable=wrong-keyword-args  # trace-all-classes
        cd_plc_file = os.path.join(self._output_plc_dir, self._cd_plc_file)
        placement_util.save_placement(self._plc, cd_plc_file, user_comments)
        cd_snapshot_file = os.path.join(
            self._output_plc_dir,
            f'snapshot_ppo_cd_placement_timestamp_{ts}_cost_{cost:.4f}.plc')
        placement_util.save_placement(self._plc, cd_snapshot_file,
                                      user_comments)

  def call_analytical_placer_and_get_cost(self) -> tuple[float, InfoType]:
    """Calls analytical placer.

    Calls analystical placer and evaluates cost when all nodes are placed. Also,
    saves the placement file for eval if all the macros are placed by RL.

    Returns:
      A tuple for placement cost and info.
    """
    if self._done:
      self.analytical_placer()
    # Only evaluates placement cost when all nodes are placed.
    # All samples in the episode receive the same reward equal to final cost.
    # This is realized by setting intermediate steps cost as zero, and
    # propagate the final cost with discount factor set to 1 in replay buffer.
    cost, info = self._cost_info_fn(self._plc, self._done)
    # OS
    for node_index in placement_util.nodes_of_types(self._plc, ['MACRO']):
      if self._plc.is_node_soft_macro(node_index):
        x_pos, y_pos = self._plc.get_node_location(node_index)
        self._plc_os.set_soft_macro_position(node_index, x_pos, y_pos)

    cost_os, info_os = self._cost_info_fn(self._plc_os, self._done)

    # Discrep Detection
    if DEBUG and abs(cost_os - cost) >= 1e-2 and self._current_node == self._num_hard_macros:
      logging.info('*****DISCREPENCY FOUND IN PROXY COST*****')
      cd_plc_file = './failed_proxy_plc/' + str(cost) + '_vs_' + str(cost_os)
      comment = '***GL***\ncongestion cost:{}\nwirelength cost:{}\ndensity cost:{}\n'\
        .format(self._plc.get_congestion_cost(), self._plc.get_cost(), self._plc.get_density_cost())
      comment += 'canvas_width_height:{}' + str(self._plc.get_canvas_width_height())
      comment += 'get_grid_num_columns_rows:{}' + str(self._plc.get_grid_num_columns_rows())
      
      comment += '\n***OS***\ncongestion cost:{}\nwirelength cost:{}\ndensity cost:{}\n'\
        .format(self._plc_os.get_congestion_cost(), self._plc_os.get_cost(), self._plc_os.get_density_cost())
      
      
      placement_util.save_placement(self._plc, cd_plc_file, comment)
      placement_util.save_placement(self._plc_os, cd_plc_file+"os", comment)
      # also save all coordinate
      with open('./failed_proxy_coord/{}_vs_{}.npy'.format(str(cost), str(cost_os)), 'wb') as f:
        # GL
        np.save(f, np.array(list(placement_util.get_node_xy_coordinates(self._plc).items())))
        # OS
        np.save(f, np.array(list(placement_util.get_node_xy_coordinates(self._plc_os).items())))
    else:
      logging.info('* proxy cost matched *')

    # We only save placement if all nodes by placed RL, because the dreamplace
    # mix-sized placement may not be legal.
    if self._current_node == self._num_hard_macros and self._is_eval:
      self._save_placement(cost)

    return -cost_os, info

  def reset(self) -> ObsType:
    """Resets the environment.

    Returns:
      An initial observation.
    """
    self._hash = random.randint(0, sys.maxsize)

    self._plc.unplace_all_nodes()
    #OS
    self._plc_os.unplace_all_nodes()
    self._current_actions = []
    self._current_node = 0
    self._done = False
    # OOM
    self._current_mask = self._get_mask()
    self._current_mask_os = self._get_mask_os()
    
    # OOM
    obs = self._get_obs()
    obs_os = self._get_obs_os()

    if DEBUG:
      for feature_gl, feature_os in zip(obs, obs_os):
        if not (obs[feature_gl] == obs_os[feature_os]).all():
          logging.info('*****DISCREPENCY FOUND IN OBSERVATION*****')
          with open('./failed_obs/reset_{}_feature_{}.npy'.format(str(self._hash), str(feature_gl)+'@'+str(feature_os)), 'wb') as f:
            # GL
            np.save(f, np.array(obs[feature_gl]))
            # OS
            np.save(f, np.array(obs_os[feature_os]))

    return obs_os

  def translate_to_original_canvas(self, action: int) -> int:
    """Translates a raw location to real one in the original canvas."""
    up_pad = (self._observation_config.max_grid_size - self._grid_rows) // 2
    right_pad = (self._observation_config.max_grid_size - self._grid_cols) // 2

    a_i = action // self._observation_config.max_grid_size - up_pad
    a_j = action % self._observation_config.max_grid_size - right_pad

    if 0 <= a_i < self._grid_rows or 0 <= a_j < self._grid_cols:
      action = a_i * self._grid_cols + a_j
    else:
      #OS
      raise InfeasibleActionError(action, self._current_mask_os)
    return action

  def place_node(self, node_index: int, action: int) -> None:
    print(">>>>GL: " + str(self.translate_to_original_canvas(action)))
    self._plc.place_node(node_index, self.translate_to_original_canvas(action))
    #OS
    print(">>>>OS: " + str(self.translate_to_original_canvas(action)))
    self._plc_os.place_node(node_index, self.translate_to_original_canvas(action))

    # print(">>>>GL Placed {}: {}, OS Placed {}: {}".format(str(node_index), str(self._plc.get_node_location(node_index)), str(node_index), str(self._plc_os.get_node_location(node_index))))

  def analytical_placer(self) -> None:
    if self._std_cell_placer_mode == 'fd':
      placement_util.fd_placement_schedule(self._plc)
    else:
      raise ValueError('%s is not a supported std_cell_placer_mode.' %
                       (self._std_cell_placer_mode))

  def step(self, action: int) -> Tuple[ObsType, float, bool, Any]:
    """Steps the environment.

    Args:
      action: The action to take (should be a list of size 1).

    Returns:
      observation, reward, done, and info.

    Raises:
      RuntimeError: action taken after episode was done
      InfeasibleActionError: bad action taken (action is not in feasible
        actions)
    """
    if self._done:
      raise RuntimeError('Action taken after episode is done.')

    action = int(action)
    self._current_actions.append(action)
    if self._current_mask_os[action] == 0:
      raise InfeasibleActionError(action, self._current_mask_os)

    node_index = self._sorted_node_indices_os[self._current_node]
    self.place_node(node_index, action) # OS place at the same time

    self._current_node += 1
    self._done = (self._current_node == self._num_hard_macros)
    self._current_mask = self._get_mask()
    self._current_mask_os = self._get_mask_os() # OS

    # Discrep Detection
    if DEBUG and not (np.array(self._current_mask) == np.array(self._current_mask_os)).all():
      logging.info('*****DISCREPENCY FOUND IN CURRENT MASK*****')
      with open('./failed_mask/action_{}_node_{}.npy'.format(str(action), str(node_index)), 'wb') as f:
        # GL
        np.save(f, np.array(self._current_mask))
        # OS
        np.save(f, np.array(self._current_mask_os))
    else:
      logging.info('* node mask matched *')
    
    if not self._done and not np.any(self._current_mask_os):
      logging.info('Actions took before becoming infeasible: %s',
                   self._current_actions)
      info = {
          'wirelength': -1.0,
          'congestion': -1.0,
          'density': -1.0,
      }
      return self.reset(), self.INFEASIBLE_REWARD, True, info

    cost, info = self.call_analytical_placer_and_get_cost()

    # OS
    # OOM
    obs = self._get_obs()
    obs_os = self._get_obs_os()

    if DEBUG:
      for feature_gl, feature_os in zip(obs, obs_os):
        if not (obs[feature_gl] == obs_os[feature_os]).all() and not _done:
          logging.info('*****DISCREPENCY FOUND IN OBSERVATION*****')
          with open('./failed_obs/step_{}_feature_{}.npy'.format(str(self._hash), str(feature_gl)+'@'+str(feature_os)), 'wb') as f:
            # GL
            np.save(f, np.array(obs[feature_gl]))
            # OS
            np.save(f, np.array(obs_os[feature_os]))

    return obs_os, cost, self._done, info


def create_circuit_environment(*args, **kwarg) -> wrappers.ActionClipWrapper:
  """Create an `CircuitEnv` wrapped as a Gym environment.

  Args:
    *args: Arguments.
    **kwarg: keyworded Arguments.

  Returns:
    PyEnvironment used for training.
  """
  env = CircuitEnv(*args, **kwarg)

  return wrappers.ActionClipWrapper(suite_gym.wrap_env(env))
