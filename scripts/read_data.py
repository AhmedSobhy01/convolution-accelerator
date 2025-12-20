import math

skip_lines_from_end = 4

with open('tb/inputdata.data', 'r') as f:
    elements = [line.strip() for line in f if line.strip()]

# Skip the last N lines
if skip_lines_from_end > 0:
    elements = elements[:-skip_lines_from_end]

n = int(math.sqrt(len(elements)))
if n * n != len(elements):
    raise ValueError("Number of elements is not a perfect square.")

for i in range(n):
    row_dec = [str(int(x, 16)) for x in elements[i * n:(i + 1) * n]]
    print(' '.join(row_dec))
