import collections
import functools
import os
import time
from typing import Text
import statistics
import re

from absl import app
from absl import flags
from absl.flags import argparse_flags
from circuit_training.environment import environment
from circuit_training.environment import placement_util
from tf_agents.experimental.distributed import reverb_variable_container
from tf_agents.metrics import py_metric
from tf_agents.metrics import py_metrics
from tf_agents.policies import greedy_policy  # pylint: disable=unused-import
from tf_agents.policies import py_tf_eager_policy
from tf_agents.policies import policy_loader
from tf_agents.train import actor
from tf_agents.train import learner
from tf_agents.train.utils import train_utils
from tf_agents.trajectories import trajectory
from tf_agents.utils import common
from tf_agents.policies import greedy_policy  # pylint: disable=unused-import
from tf_agents.system import system_multiprocessing as multiprocessing

"""
Example
    At ./MacroPlacement/CodeElement/EvalCT, run the following command:

        $ cd EvalCT && python3 -m eval_ct --netlist ./test/ariane/netlist.pb.txt\
            --plc ./test/ariane/initial.plc\
            --rundir run_00\
            --ckptID policy_checkpoint_0000103984\
            && cd -

"""
# InfoMetric_wirelength = 0.09238692254177283
# 		 InfoMetric_congestion = 0.9468230846211636
# 		 InfoMetric_density = 0.5462616496124097


class InfoMetric(py_metric.PyStepMetric):
    """Observer for graphing the environment info metrics."""

    def __init__(
        self,
        env,
        info_metric_key: Text,
        buffer_size: int = 1,
        name: Text = 'InfoMetric',
    ):
        """Observer reporting TensorBoard metrics at the end of each episode.

        Args:
        env: environment.
        info_metric_key: a string key from the environment info to report,
            e.g. wirelength, density, congestion.
        buffer_size: size of the buffer for calculating the aggregated metrics.
        name: name of the observer object.
        """
        super(InfoMetric, self).__init__(name + '_' + info_metric_key)

        self._env = env
        self._info_metric_key = info_metric_key
        self._buffer = collections.deque(maxlen=buffer_size)

    def call(self, traj: trajectory.Trajectory):
        """Report the requested metrics at the end of each episode."""

        # We collect the metrics from the info from the environment instead.
        # The traj argument is kept to be compatible with the actor/learner API
        # for metrics.
        del traj

        if self._env.done:
            # placement_util.save_placement(self._env._plc, './reload_weight.plc', '')
            metric_value = self._env.get_info()[self._info_metric_key]
            self._buffer.append(metric_value)

    def result(self):
        return statistics.mean(self._buffer)

    def reset(self):
        self._buffer.clear()

def evaulate(model_dir, ckpt_id, create_env_fn):
    # Create the path for the serialized greedy policy.
    policy_saved_model_path = os.path.join(model_dir,
                                           learner.POLICY_SAVED_MODEL_DIR,
                                           learner.GREEDY_POLICY_SAVED_MODEL_DIR)
    try:
        assert os.path.isdir(policy_saved_model_path) 
        print("#[POLICY SAVED MODEL PATH] " + policy_saved_model_path)
    except AssertionError:
        print("[ERROR POLICY SAVED MODEL PATH NOT FOUND] " + policy_saved_model_path)
        exit(0)

    policy_saved_chkpt_path = os.path.join(model_dir,
                                         learner.POLICY_SAVED_MODEL_DIR,
                                         "checkpoints", ckpt_id)
    try:
        assert os.path.isdir(policy_saved_chkpt_path)
        print("#[POLICY SAVED CHECKPOINT PATH] " + policy_saved_chkpt_path)
    except AssertionError:
        print("[ERROR POLICY SAVED CHECKPOINT PATH NOT FOUND] " + policy_saved_chkpt_path)
        exit(0)

    saved_model_pb_path = os.path.join(policy_saved_model_path, 'saved_model.pb')

    try:
        assert os.path.isfile(saved_model_pb_path)
        print("#[SAVED MODEL PB PATH] " + saved_model_pb_path)
    except AssertionError:
        print("[ERROR SAVE MODEL PB PATH NOT FOUND] " + saved_model_pb_path)
        exit(0)

    policy = policy_loader.load(policy_saved_model_path, policy_saved_chkpt_path)

    policy.get_initial_state()

    print(policy.variables()[0].numpy())

    train_step = train_utils.create_train_step()

    # Create the environment.
    env = create_env_fn()

    # Create the evaluator actor.
    info_metrics = [
        InfoMetric(env, 'wirelength'),
        InfoMetric(env, 'congestion'),
        InfoMetric(env, 'density'),
    ]

    eval_actor = actor.Actor(
      env,
      policy,
      train_step,
      episodes_per_run=1,
      summary_dir=os.path.join(model_dir, learner.TRAIN_DIR, 'eval'),
      metrics=[
          py_metrics.NumberOfEpisodes(),
          py_metrics.EnvironmentSteps(),
          py_metrics.AverageReturnMetric(
              name='eval_episode_return', buffer_size=1),
          py_metrics.AverageEpisodeLengthMetric(buffer_size=1),
      ] + info_metrics,
      name='performance')

    eval_actor.run_and_log()


def main(args):
    NETLIST_FILE = args.netlist
    INIT_PLACEMENT = args.plc
    POLICY_CHECKPOINT_ID = args.ckptID
    GLOBAL_SEED = 111
    CD_RUNTIME = False
    RUN_NAME = args.rundir

    # extract eval testcase name
    EVAL_TESTCASE = re.search("/test/(.+?)/netlist.pb.txt", NETLIST_FILE).group(1)

    create_env_fn = functools.partial(
        environment.create_circuit_environment,
        netlist_file=NETLIST_FILE,
        init_placement=INIT_PLACEMENT,
        is_eval=True,
        save_best_cost=True,
        output_plc_file=str('./eval_' + RUN_NAME + '_to_' + EVAL_TESTCASE + '.plc'),
        global_seed=GLOBAL_SEED,
        cd_finetune=CD_RUNTIME
    )

    evaulate(model_dir=os.path.join("./saved_policy", RUN_NAME, str(GLOBAL_SEED)), 
                ckpt_id=POLICY_CHECKPOINT_ID, create_env_fn=create_env_fn) 

def parse_flags(argv):
    parser = argparse_flags.ArgumentParser(
        description='An argparse + app.run example')
    parser.add_argument("--netlist", required=True,
                        help="Path to netlist in pb.txt")
    parser.add_argument("--plc", required=True,
                        help="Path to plc in .plc")
    parser.add_argument("--rundir", required=True,
                        help="Path to run directory that contains saved policies")
    parser.add_argument("--ckptID", required=True,
                        help="Policy checkpoint ID")

    return parser.parse_args(argv[1:])

if __name__ == '__main__':
    app.run(main, flags_parser=parse_flags)