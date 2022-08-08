# PlacementCost Class:
*Circuit Training Open Source* is an effort to open-source the entire framework for generating chip floor plans
with distributed deep reinforcement learning. This framework is originally reproduces the
methodology published in the Nature 2021 paper:
*[A graph placement methodology for fast chip design.](https://www.nature.com/articles/s41586-021-03544-w)
Azalia Mirhoseini, Anna Goldie, Mustafa Yazgan, Joe Wenjie Jiang, Ebrahim
Songhori, Shen Wang, Young-Joon Lee, Eric Johnson, Omkar Pathak, Azade Nazi,
Jiwoo Pak, Andy Tong, Kavya Srinivasa, William Hang, Emre Tuncer, Quoc V. Le,
James Laudon, Richard Ho, Roger Carpenter & Jeff Dean, 2021. Nature, 594(7862),
pp.207-212.
[[PDF]](https://www.nature.com/articles/s41586-021-03544-w.epdf?sharing_token=tYaxh2mR5EozfsSL0WHZLdRgN0jAjWel9jnR3ZoTv0PW0K0NmVrRsFPaMa9Y5We9O4Hqf_liatg-lvhiVcYpHL_YQpqkurA31sxqtmA-E1yNUWVMMVSBxWSp7ZFFIWawYQYnEXoBE4esRDSWqubhDFWUPyI5wK_5B_YIO-D_kS8%3D)*

## Quick Start
Under `MACROPLACEMENT` main directory, run the following command:
```
python -m Plc_client.plc_client_os_test

```

## What do we open-source here?
The current Circuit Training framework requires user to download an executable binary <em>plc_wrapper_main</em> in order to run. The <em>plc_wrapper_main</em> is not open-sourced and not documented anywhere publically. [plc_client.py](https://github.com/google-research/circuit_training/blob/main/circuit_training/environment/plc_client.py) then talks to this binary excutable for crtical information to build a training environment, extract a state observation and even call a force-directed placer. This is an attempt to open-source this "last piece" to the puzzle and hopefully reproduce a fully transparent framework to the public.

## How do I open-source?

All current progress can be reviewed [here](https://github.com/Dinple/circuit_training_os/blob/main/circuit_training/environment/plc_client_os.py). I have generated numerous testcases, varying from a few macros to hundreds of different modules. The purpose of these testcases is to study the behavior of <em>plc_wrapper_main</em> in a scalable way. I have also set up testbench to compare my result to the result from [plc_client.py](https://github.com/Dinple/circuit_training_os/blob/main/circuit_training/environment/plc_client.py).

## What is the end-goal?

The first step and the current step of this open-source effor is to reproduce similar results to Google's <em>plc_wrapper_main</em> in the testbench. The final step will be plugging [plc_client_os.py](https://github.com/Dinple/circuit_training_os/blob/main/circuit_training/environment/plc_client_os.py) into the Circuit Training Framework and reproduce a quality training.

## Reference

```
@article{mirhoseini2021graph,
  title={A graph placement methodology for fast chip design},
  author={Mirhoseini, Azalia and Goldie, Anna and Yazgan, Mustafa and Jiang, Joe
  Wenjie and Songhori, Ebrahim and Wang, Shen and Lee, Young-Joon and Johnson,
  Eric and Pathak, Omkar and Nazi, Azade and Pak, Jiwoo and Tong, Andy and
  Srinivasa, Kavya and Hang, William and Tuncer, Emre and V. Le, Quoc and
  Laudon, James and Ho, Richard and Carpenter, Roger and Dean, Jeff},
  journal={Nature},
  volume={594},
  number={7862},
  pages={207--212},
  year={2021},
  publisher={Nature Publishing Group}
}
```

```
@misc{CircuitTraining2021,
  title = {{Circuit Training}: An open-source framework for generating chip
  floor plans with distributed deep reinforcement learning.},
  author = {Guadarrama, Sergio and Yue, Summer and Boyd, Toby and Jiang, Joe
  Wenjie and Songhori, Ebrahim and Tam, Terence and Mirhoseini, Azalia},
  howpublished = {\url{https://github.com/google_research/circuit_training}},
  url = "https://github.com/google_research/circuit_training",
  year = 2021,
  note = "[Online; accessed 21-December-2021]"
}
```