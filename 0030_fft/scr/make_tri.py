from __future__ import print_function
import math

phases = [2*math.pi*x/8.0 for x in [3, 1, 2, 0]]
triv = [[0xFF & math.floor(2**6*x + 0.5) for x in [math.sin(p), math.cos(p)]]
        for p in phases]
print("\n, ".join([', '.join(['8\'h{:02X}'.format(x)
                              for x in v])
                  for v in triv]))

#print(triv)
