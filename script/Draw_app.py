import os
import sys
import threading
import tkinter as tk

# =========================================================================
# CÁCH LY MÔI TRƯỜNG QUARTUS & PYTHON TKINTER
# =========================================================================
# if not os.environ.get('CLEANED_FOR_TKINTER'):
#     for var in ['LD_LIBRARY_PATH', 'TCL_LIBRARY', 'TK_LIBRARY']:
#         if var in os.environ:
#             os.environ[f'Q_{var}'] = os.environ[var]
#             del os.environ[var]
#     os.environ['CLEANED_FOR_TKINTER'] = '1'
#     os.execl(sys.executable, sys.executable, *sys.argv)

class QuickDrawGUI:
    def __init__(self, root):
        self.root = root
        self.root.title("Quick Draw BNN - AI Canvas")
        
        self.canvas = tk.Canvas(root, width=320, height=320, bg='white', cursor="pencil")
        self.canvas.pack(pady=10)
        
        self.canvas.bind("<B1-Motion>", self.paint)
        self.canvas.bind("<Button-1>", self.paint_start)
        self.canvas.bind("<ButtonRelease-1>", self.paint_end)
        
        self.btn_frame = tk.Frame(root)
        self.btn_frame.pack(pady=5)
        
        self.btn_clear = tk.Button(self.btn_frame, text="Xóa Bảng (Clear)", command=self.clear, width=15)
        self.btn_clear.pack(side=tk.LEFT, padx=10)
        
        self.btn_send = tk.Button(self.btn_frame, text="Chạy AI (Send JTAG)", command=self.send_to_fpga, bg="green", fg="white", width=15)
        self.btn_send.pack(side=tk.LEFT, padx=10)
        
        self.img_matrix = [[0]*32 for _ in range(32)]
        self.last_x = None
        self.last_y = None

    def apply_brush(self, cx, cy):
        # Thầy mở rộng cọ vẽ lên 3x3 để AI nhận diện nét rõ hơn (Khắc phục lỗi toàn ra Class 1)
        for dx in range(-1, 2):
            for dy in range(-1, 2):
                nx, ny = cx + dx, cy + dy
                if 0 <= nx < 32 and 0 <= ny < 32:
                    self.img_matrix[ny][nx] = 1

    def bresenham_line(self, x0, y0, x1, y1):
        dx = abs(x1 - x0)
        dy = abs(y1 - y0)
        sx = 1 if x0 < x1 else -1
        sy = 1 if y0 < y1 else -1
        err = dx - dy
        while True:
            self.apply_brush(x0, y0)
            if x0 == x1 and y0 == y1: break
            e2 = 2 * err
            if e2 > -dy:
                err -= dy
                x0 += sx
            if e2 < dx:
                err += dx
                y0 += sy

    def paint_start(self, event):
        self.last_x, self.last_y = event.x // 10, event.y // 10
        self.apply_brush(self.last_x, self.last_y)
        self.draw_gui_line(event.x, event.y, event.x, event.y)

    def paint(self, event):
        cx, cy = event.x // 10, event.y // 10
        if self.last_x is not None and self.last_y is not None:
            self.bresenham_line(self.last_x, self.last_y, cx, cy)
            self.draw_gui_line(self.last_x * 10 + 5, self.last_y * 10 + 5, event.x, event.y)
        self.last_x, self.last_y = cx, cy

    def paint_end(self, event):
        self.last_x = None
        self.last_y = None

    def draw_gui_line(self, x1, y1, x2, y2):
        self.canvas.create_line(x1, y1, x2, y2, width=10, fill='black', capstyle=tk.ROUND, smooth=True)

    def clear(self):
        self.canvas.delete("all")
        self.img_matrix = [[0]*32 for _ in range(32)]
        
    def send_to_fpga(self):
        self.btn_send.config(text="Đang gửi...", state=tk.DISABLED, bg="grey")

        def jtag_task():
            mif_filename = "live_image.mif"
            with open(mif_filename, "w") as f:
                f.write("DEPTH = 1024;\nWIDTH = 1;\nADDRESS_RADIX = DEC;\nDATA_RADIX = BIN;\nCONTENT BEGIN\n")
                idx = 0
                for y in range(32):
                    for x in range(32):
                        f.write(f"{idx} : {self.img_matrix[y][x]};\n")
                        idx += 1
                f.write("END;\n")
            
            print("\n====================================================")
            print(f"[*] Đã xuất {mif_filename}. Đang nạp qua JTAG...")
            
            # Phục hồi biến môi trường
            for var in ['LD_LIBRARY_PATH', 'TCL_LIBRARY', 'TK_LIBRARY']:
                if f'Q_{var}' in os.environ:
                    os.environ[var] = os.environ[f'Q_{var}']
            
            # Chạy JTAG thuần túy theo đúng code cũ của em
            os.system(r'"C:\intelFPGA_lite\20.1\quartus\bin64\quartus_stp.exe" -t run_fpga.tcl')
            
            # Xóa biến môi trường trả lại cho Tkinter
            for var in ['LD_LIBRARY_PATH', 'TCL_LIBRARY', 'TK_LIBRARY']:
                if var in os.environ:
                    del os.environ[var]
            
            # --- Cập nhật đúng Bảng tra cứu nhãn 10 classes mới ---
            class_map = ['apple', 'clock', 'star', 'bicycle', 'cookie', 
                         'moon', 'sword', 'tree', 't-shirt', 'lightning']
            print("\nĐÃ SUY LUẬN XONG!")
            print("BẢNG TRA CỨU NHÃN DỰ ĐOÁN:")
            for i, name in enumerate(class_map):
                print(f"CLASS [{i}]: {name.upper()}")
            
            print("====================================================")
            self.root.after(0, lambda: self.btn_send.config(text="Chạy AI (Send JTAG)", state=tk.NORMAL, bg="green"))

        threading.Thread(target=jtag_task, daemon=True).start()

if __name__ == "__main__":
    root = tk.Tk()
    app = QuickDrawGUI(root)
    root.mainloop()