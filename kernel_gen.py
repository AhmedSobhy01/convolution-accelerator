K = 12
concatenated = ""

real_kernel_concat = ""

actual_rows = []

for i in range(K*K):
    real_kernel_concat = f"{i+1:02X}" + real_kernel_concat
    if (i + 1) % K == 0:
        actual_rows.append(real_kernel_concat)
        real_kernel_concat = ""

    concatenated = f"{i+1:02X}" + concatenated
    if ((i + 1) % 4 == 0):
        print(f"{int(concatenated, 16):08X}")
        concatenated = ""


for row in actual_rows:
    print(row)

# printing the 4 quadrants
if K > 8:
    print("\nQuadrant 0:")
    for i in range(K//2):
        print(f"{int(actual_rows[i][K: K*2], 16):016X}")

    print("\nQuadrant 1:")
    for i in range(K//2):
        print(f"{int(actual_rows[i][: K], 16):016X}")

    print("\nQuadrant 2:")
    for i in range(K//2, K):
        print(f"{int(actual_rows[i][K: K*2], 16):016X}")
    print("\nQuadrant 3:")
    for i in range(K//2, K):
        print(f"{int(actual_rows[i][: K], 16):016X}")
else:
    print("\nQuadrant 0:")
    for i in range(K):
        print(f"{int(actual_rows[i], 16):08X}")

