import numpy as np

# Nạp 4 file text (Dùng np.atleast_1d để tránh lỗi khi file chỉ chứa 1 giá trị)
mean  = np.atleast_1d(np.loadtxt('fc2_bn_mean.txt'))
var   = np.atleast_1d(np.loadtxt('fc2_bn_var.txt'))
gamma = np.atleast_1d(np.loadtxt('fc2_bn_gamma.txt'))
beta  = np.atleast_1d(np.loadtxt('fc2_bn_beta.txt'))

epsilon = 1e-5

# Dùng Q4.12 (1 bit sign, 3 bit integer, 12 bit fraction)
TOTAL_BITS = 16
FRAC_BITS = 12  
scale = 1 << FRAC_BITS

# Ngưỡng Saturation (Clipping) 16-bit Signed
MIN_VAL = -(1 << (TOTAL_BITS - 1))  # -32768
MAX_VAL = (1 << (TOTAL_BITS - 1)) - 1 #  32767

sv_output = ""

# Lấy số lượng class thực tế từ file (thường là 10)
num_classes = len(mean)

for c in range(num_classes):
    lut_values = []
    for p in range(65):
        # 1. Biến đổi Popcount (0..64) -> Bipolar (-64..+64)
        x_bipolar = 2 * p - 64 
        
        # 2. Batch Normalization Formula
        score_fp = ((x_bipolar - mean[c]) / np.sqrt(var[c] + epsilon)) * gamma[c] + beta[c]
        
        # 3. Lượng tử hóa Q4.12 & Kẹp lề (Clipping)
        score_scaled = np.round(score_fp * scale)
        score_clipped = int(np.clip(score_scaled, MIN_VAL, MAX_VAL))
        
        # 4. Mã bù 2 Hex 16-bit
        if score_clipped < 0:
            score_hex = (1 << TOTAL_BITS) + score_clipped
        else:
            score_hex = score_clipped
            
        lut_values.append(f"    16'h{score_hex:04X}")
    
    # Xuất cú pháp SystemVerilog chuẩn
    sv_output += f"localparam logic signed [15:0] lut_c{c} [0:64] = '{{\n"
    sv_output += ",\n".join(lut_values)
    sv_output += "\n};\n\n"

with open("fc2_luts_q412.sv", "w") as f:
    f.write(sv_output)

print(f"Đã tạo thành công file fc2_luts_q412.sv chứa {num_classes} LUT chuẩn Q4.12!")