"""Small glTF skeleton helpers shared by the Bull rigging scripts (numpy only)."""
import numpy as np


def quat_to_mat(q):
    x, y, z, w = q
    return np.array([[1 - 2*(y*y+z*z), 2*(x*y - z*w), 2*(x*z + y*w)],
                     [2*(x*y + z*w), 1 - 2*(x*x+z*z), 2*(y*z - x*w)],
                     [2*(x*z - y*w), 2*(y*z + x*w), 1 - 2*(x*x+y*y)]])


def local_matrix(n):
    m = np.eye(4)
    s = np.array(n.get('scale', [1, 1, 1]))
    m[:3, :3] = quat_to_mat(n.get('rotation', [0, 0, 0, 1])) * s
    m[:3, 3] = n.get('translation', [0, 0, 0])
    return m


def parents(j):
    par = {}
    for i, n in enumerate(j['nodes']):
        for c in n.get('children', []):
            par[c] = i
    return par


def global_matrices(j):
    par = parents(j)
    cache = {}
    def g(i):
        if i not in cache:
            cache[i] = (g(par[i]) if i in par else np.eye(4)) @ local_matrix(j['nodes'][i])
        return cache[i]
    return {i: g(i) for i in range(len(j['nodes']))}
