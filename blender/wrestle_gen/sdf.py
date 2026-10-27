"""Vectorized signed-distance modelling and surface-nets polygonization (numpy only).

Shapes are built from primitives combined with smooth unions/subtractions, then
polygonized on a regular grid. Every primitive is tagged with a bone so skin weights
can be derived from the same distances.
"""
import numpy as np

INF = np.float32(1e6)


def _len(v):
    return np.sqrt(np.einsum("...i,...i->...", v, v))


def _frame(axis):
    """Orthonormal 3x3 matrix whose first row is `axis`."""
    x = np.asarray(axis, np.float64)
    x = x / np.linalg.norm(x)
    up = np.array([0.0, 0.0, 1.0]) if abs(x[2]) < 0.9 else np.array([0.0, 1.0, 0.0])
    y = np.cross(up, x)
    y /= np.linalg.norm(y)
    z = np.cross(x, y)
    return np.stack([x, y, z])


# ---------------------------------------------------------------- primitives

def sphere(p, c, r):
    return _len(p - np.asarray(c, np.float32)) - r


def ellipsoid(p, c, radii, axis=None):
    """Ellipsoid centred at c. With `axis`, radii[0] lies along that direction."""
    q = p - np.asarray(c, np.float32)
    if axis is not None:
        q = q @ _frame(axis).T.astype(np.float32)
    r = np.asarray(radii, np.float32)
    k0 = _len(q / r)
    k1 = _len(q / (r * r))
    return k0 * (k0 - 1.0) / np.maximum(k1, 1e-9)


def round_cone(p, a, b, r1, r2):
    """Capsule from a (radius r1) to b (radius r2). After Inigo Quilez."""
    a = np.asarray(a, np.float32)
    ba = np.asarray(b, np.float32) - a
    l2 = float(ba @ ba)
    rr = r1 - r2
    a2 = l2 - rr * rr
    il2 = 1.0 / l2
    pa = p - a
    y = pa @ ba
    z = y - l2
    xv = pa * l2 - y[:, None] * ba
    x2 = np.einsum("ij,ij->i", xv, xv)
    y2 = y * y * l2
    z2 = z * z * l2
    k = np.sign(rr) * rr * rr * x2
    return np.where(
        np.sign(z) * a2 * z2 > k, np.sqrt(x2 + z2) * il2 - r2,
        np.where(np.sign(y) * a2 * y2 < k, np.sqrt(x2 + y2) * il2 - r1,
                 (np.sqrt(np.maximum(x2 * a2 * il2, 0)) + y * rr) * il2 - r1))


def half_space(p, normal, offset):
    """Inside where dot(p, normal) > offset."""
    n = np.asarray(normal, np.float32)
    n = n / np.linalg.norm(n)
    return offset - p @ n


def smin(a, b, k):
    if k <= 0:
        return np.minimum(a, b)
    h = np.maximum(k - np.abs(a - b), 0.0) / k
    return np.minimum(a, b) - h * h * k * 0.25


def smax(a, b, k):
    return -smin(-a, -b, k)


# ---------------------------------------------------------------- shape model

class Prim:
    """One primitive. op: 'add' (smooth union), 'sub' (smooth subtract), 'and' (smooth intersect)."""

    def __init__(self, fn, bone=None, k=0.02, op="add", **params):
        self.fn, self.bone, self.k, self.op, self.params = fn, bone, k, op, params

    def eval(self, p):
        return self.fn(p, **self.params)


class Shape:
    def __init__(self, prims):
        self.prims = list(prims)

    def eval(self, p, want_bones=False):
        p = np.asarray(p, np.float32)
        d = np.full(len(p), INF, np.float32)
        bones = {}
        for pr in self.prims:
            di = pr.eval(p).astype(np.float32)
            if pr.op == "add":
                d = smin(d, di, pr.k)
                if want_bones and pr.bone:
                    prev = bones.get(pr.bone)
                    bones[pr.bone] = di if prev is None else np.minimum(prev, di)
            elif pr.op == "sub":
                d = smax(d, -di, pr.k)
            elif pr.op == "and":
                d = smax(d, di, pr.k)
        return (d, bones) if want_bones else d

    def eval_chunked(self, p, chunk=400_000):
        out = np.empty(len(p), np.float32)
        for i in range(0, len(p), chunk):
            out[i:i + chunk] = self.eval(p[i:i + chunk])
        return out

    def gradient(self, p, h=1e-3):
        g = np.empty_like(p)
        for i in range(3):
            o = np.zeros(3, np.float32)
            o[i] = h
            g[:, i] = (self.eval(p + o) - self.eval(p - o)) / (2 * h)
        return g

    def project(self, p, iters=3):
        """Move points onto the zero surface along the field gradient."""
        p = p.astype(np.float32).copy()
        for _ in range(iters):
            d = self.eval(p)
            g = self.gradient(p)
            g2 = np.maximum(np.einsum("ij,ij->i", g, g), 1e-8)
            p -= g * (d / g2)[:, None]
        return p


# ---------------------------------------------------------------- meshing

_CORNERS = np.array([(0, 0, 0), (1, 0, 0), (0, 1, 0), (1, 1, 0),
                     (0, 0, 1), (1, 0, 1), (0, 1, 1), (1, 1, 1)])
_EDGES = [(0, 1), (2, 3), (4, 5), (6, 7), (0, 2), (1, 3),
          (4, 6), (5, 7), (0, 4), (1, 5), (2, 6), (3, 7)]


def polygonize(shape, bmin, bmax, h):
    """Naive surface nets. Returns (verts Nx3, quads Mx4)."""
    bmin = np.asarray(bmin, np.float32)
    n = np.ceil((np.asarray(bmax, np.float32) - bmin) / h).astype(int) + 1
    axes = [bmin[i] + h * np.arange(n[i], dtype=np.float32) for i in range(3)]
    gx, gy, gz = np.meshgrid(*axes, indexing="ij")
    pts = np.stack([gx.ravel(), gy.ravel(), gz.ravel()], 1)
    F = shape.eval_chunked(pts).reshape(n)
    inside = F < 0

    nx, ny, nz = n
    cf = [F[i:nx - 1 + i, j:ny - 1 + j, k:nz - 1 + k] for i, j, k in _CORNERS]
    any_in = np.zeros(cf[0].shape, bool)
    all_in = np.ones(cf[0].shape, bool)
    for c in cf:
        any_in |= c < 0
        all_in &= c < 0
    active = any_in & ~all_in
    cells = np.argwhere(active)
    vmap = -np.ones(active.shape, np.int64)
    vmap[active] = np.arange(len(cells))

    ci = tuple(cells.T)
    vals = [c[ci] for c in cf]
    acc = np.zeros((len(cells), 3), np.float32)
    cnt = np.zeros(len(cells), np.float32)
    for a, b in _EDGES:
        va, vb = vals[a], vals[b]
        cross = (va < 0) != (vb < 0)
        t = np.where(cross, va / np.where(cross, va - vb, 1.0), 0.0)
        pt = _CORNERS[a] + t[:, None] * (_CORNERS[b] - _CORNERS[a])
        acc[cross] += pt[cross]
        cnt[cross] += 1
    verts = bmin + (cells + acc / cnt[:, None]) * h

    quads = []
    for axis in range(3):
        u, v = (axis + 1) % 3, (axis + 2) % 3
        s0 = [slice(None)] * 3
        s1 = [slice(None)] * 3
        s0[axis], s1[axis] = slice(0, -1), slice(1, None)
        in0 = inside[tuple(s0)]
        crossing = in0 != inside[tuple(s1)]
        pts_e = np.argwhere(crossing)
        ok = ((pts_e[:, u] >= 1) & (pts_e[:, v] >= 1)
              & (pts_e[:, u] <= n[u] - 2) & (pts_e[:, v] <= n[v] - 2))
        pts_e = pts_e[ok]
        flip = in0[tuple(pts_e.T)]

        def cell(du, dv):
            c = pts_e.copy()
            c[:, u] -= du
            c[:, v] -= dv
            return vmap[tuple(c.T)]

        q = np.stack([cell(1, 1), cell(0, 1), cell(0, 0), cell(1, 0)], 1)
        q[flip] = q[flip][:, ::-1]
        quads.append(q)
    return verts, np.concatenate(quads)
