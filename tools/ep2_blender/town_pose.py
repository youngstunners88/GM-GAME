"""Shared T-pose -> stance vertex maths for the founder town characters (see prep_founder_town_models.py)."""
import math
import bpy


def select_only(o):
    bpy.ops.object.select_all(action="DESELECT")
    o.select_set(True)
    bpy.context.view_layer.objects.active = o


def smoothstep(x, e0, e1):
    import numpy as np
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def fit_arms(o):
    """Shoulder pivot / arm band from the T-pose mesh itself (any Tripo scale): arm height = the height of the farthest-out vertices; all other
    numbers are fractions of the body height (measured on the founder's Jake: pivot x .122 H, band -.078 H / +.113 H, fade .113 H .. .209 H)."""
    import numpy as np
    me = o.data
    n = len(me.vertices)
    co = np.empty(n * 3, dtype=np.float64)
    me.vertices.foreach_get('co', co)
    co = co.reshape(n, 3)
    H = co[:, 2].max() - co[:, 2].min()
    zmin = co[:, 2].min()
    far = np.abs(co[:, 0]) > 0.85 * np.abs(co[:, 0]).max()
    za = float(co[far, 2].mean())
    return dict(pivot_z=za, pivot_x=0.122 * H, z0=za - 0.078 * H, z1=za + 0.113 * H, x0=0.113 * H, x1=0.209 * H), H, zmin


def deform_arms(o, pitch_l=55.0, pitch_r=55.0, swing_l=0.0, swing_r=0.0, pivot_z=0.83, pivot_x=0.14, z0=0.74, z1=0.96, x0=0.13, x1=0.24, auto=False):
    """T-pose -> A-pose (or any arm pose) by rotating the arm vertices about each shoulder: `pitch` swings the arm down about the model's
    depth axis, `swing` then swings it forward about the vertical axis (negative = back). Weights fade in between x0 and x1 so the coat
    shoulder stays put. Pure vertex math (no rig) - the model is static in game; the stride is a bob."""
    import numpy as np
    if auto:
        fit, _, _ = fit_arms(o)
        pivot_z, pivot_x, z0, z1, x0, x1 = fit['pivot_z'], fit['pivot_x'], fit['z0'], fit['z1'], fit['x0'], fit['x1']
    me = o.data
    me.polygons.foreach_set('use_smooth', [True] * len(me.polygons))
    n = len(me.vertices)
    co = np.empty(n * 3, dtype=np.float64)
    me.vertices.foreach_get('co', co)
    co = co.reshape(n, 3)
    for side, pitch, swing in ((1.0, pitch_l, swing_l), (-1.0, pitch_r, swing_r)):
        ax = co[:, 0] * side
        w = smoothstep(ax, x0, x1) * ((co[:, 2] > z0) & (co[:, 2] < z1))
        piv = np.array([pivot_x * side, 0.0, pivot_z])
        rel = co - piv
        th = math.radians(pitch) * side
        c, s_ = math.cos(th), math.sin(th)
        # rotation about Y: x' = x c + z s ; z' = -x s + z c
        x2 = rel[:, 0] * c + rel[:, 2] * s_
        z2 = -rel[:, 0] * s_ + rel[:, 2] * c
        y2 = rel[:, 1]
        ph = math.radians(swing) * side
        c2, s2 = math.cos(ph), math.sin(ph)
        # rotation about Z (swing forward = toward -Y): x'' = x c2 + y s2 ; y'' = -x s2 + y c2
        x3 = x2 * c2 + y2 * s2
        y3 = -x2 * s2 + y2 * c2
        new = np.stack([x3, y3, z2], axis=1) + piv
        co = co * (1.0 - w[:, None]) + new * w[:, None]
    me.vertices.foreach_set('co', co.reshape(-1))
    me.update()
    select_only(o)
    try:
        bpy.ops.mesh.customdata_custom_splitnormals_clear()
    except Exception:
        pass
    me.update()


