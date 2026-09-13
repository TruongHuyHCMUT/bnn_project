# 1. Lấy Hardware và Device (FPGA Fabric - Index 1)
set hw_name [lindex [get_hardware_names] 0]
set dev_name [lindex [get_device_names -hardware_name $hw_name] 1]

puts "Hardware Selected: $hw_name"
puts "Device Selected: $dev_name"

# 2. Đường dẫn file MIF
set mif_path "D:/SOC/th_bnn_1/fpga_connect/live_image.mif"

if {![file exists $mif_path]} {
    puts "LOI: Khong tim thay file MIF tai duong dan: $mif_path"
    exit 1
}

# 3. Mở Session Edit Memory
begin_memory_edit -hardware_name $hw_name -device_name $dev_name

# Nạp dữ liệu MIF trực tiếp vào RAM Instance 0 (IMG0)
update_content_to_memory_from_file \
    -instance_index 0 \
    -mem_file_path $mif_path \
    -mem_file_type mif

# Kết thúc Session Edit Memory (Tự động ghi xuống RAM)
end_memory_edit

puts "--> Ghi RAM thanh cong!"

# 4. Kích hoạt ISSP Trigger
start_insystem_source_probe -hardware_name $hw_name -device_name $dev_name
write_source_data -instance_index 0 -value 1
after 20
write_source_data -instance_index 0 -value 0
end_insystem_source_probe

puts "--> Da phat xung Trigger sang FPGA!"