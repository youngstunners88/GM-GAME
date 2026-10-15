"""Run a command on the pod via Jupyter using pod_run.exec_cmd, with the pod's Jupyter password from env PODPW (never printed)."""
import os, sys
sys.path.insert(0, "/home/kofibeatz/Documents/GitHub/GM-GAME/tools/ep2_runpod")
import pod_run
PID = os.environ["PODID"]; PW = os.environ["PODPW"]
pod_run.jupyter = lambda pod: ("https://%s-8888.proxy.runpod.net" % PID, {"Authorization": "token " + PW})
cmd = sys.argv[1]; to = int(sys.argv[2]) if len(sys.argv) > 2 else 600
print(pod_run.exec_cmd({"id": PID}, cmd, to))
