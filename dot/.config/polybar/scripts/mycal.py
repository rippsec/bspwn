#!/usr/bin/env python3
import tkinter as tk
import calendar
import datetime
from datetime import date, timedelta
import time
import pytz
import os
import socket
import sys

class SimpleCalendar(tk.Tk):
    def __init__(self):
        super().__init__()
        
        self.title("Simple Calendar")
        self.geometry("600x400")
        self.configure(bg="#333333")
        
        # Setup socket for single instance check
        self.setup_socket()
        
        # Current date information
        self.today = date.today()
        self.current_year = self.today.year
        self.current_month = self.today.month
        
        # Selected day tracking
        self.selected_day = None
        self.selected_frame = None
        
        # Main container to center everything
        self.main_container = tk.Frame(self, bg="#333333")
        self.main_container.pack(fill="both", expand=True)  # Fill the entire window
        
        # Configure the main container to expand
        self.main_container.grid_rowconfigure(0, weight=0)  # Clock row
        self.main_container.grid_rowconfigure(1, weight=0)  # Header row
        self.main_container.grid_rowconfigure(2, weight=1)  # Calendar row
        self.main_container.grid_columnconfigure(0, weight=1)
        
        # Create frames
        self.create_clock_frame()
        self.create_header_frame()
        self.create_calendar_frame()
        self.update_calendar()
        
        # Start the clock update
        self.update_clock()
        
        # Handle window close event
        self.protocol("WM_DELETE_WINDOW", self.on_close)
    
    def setup_socket(self):
        # Use a socket to ensure single instance
        self.socket_path = "/tmp/mycalendar.sock"
        
        # Check if the socket file exists
        if os.path.exists(self.socket_path):
            # Try to connect to the existing instance
            client = socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM)
            try:
                client.connect(self.socket_path)
                # Send a command to close the existing instance
                client.send(b"CLOSE")
                client.close()
                # Exit this instance
                sys.exit(0)
            except socket.error:
                # If connection fails, remove the stale socket file
                os.unlink(self.socket_path)
        
        # Create a new socket server
        self.server = socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM)
        self.server.bind(self.socket_path)
        
        # Set up non-blocking mode
        self.server.setblocking(False)
        
        # Schedule socket check
        self.after(100, self.check_socket)
    
    def check_socket(self):
        try:
            # Check for incoming commands
            data, addr = self.server.recvfrom(1024)
            if data == b"CLOSE":
                self.on_close()
                return
        except (BlockingIOError, socket.error):
            # No data available, continue
            pass
        
        # Schedule next check
        self.after(100, self.check_socket)
    
    def on_close(self):
        # Clean up the socket
        self.server.close()
        if os.path.exists(self.socket_path):
            os.unlink(self.socket_path)
        
        # Destroy the window
        self.destroy()
        
    def create_clock_frame(self):
        clock_frame = tk.Frame(self.main_container, bg="#222222")
        clock_frame.grid(row=0, column=0, sticky="ew", padx=0, pady=0)
        
        # Clock label
        self.clock_label = tk.Label(clock_frame, text="", font=("TkDefaultFont", 12, "bold"),
                                  bg="#222222", fg="#00ff00")
        self.clock_label.pack(pady=5)
        
        # Get local timezone
        local_tz = datetime.datetime.now().astimezone().tzinfo
        self.timezone_str = f"{local_tz.tzname(datetime.datetime.now())} {time.strftime('%z')}"
    
    def update_clock(self):
        # Get current time
        current_time = time.strftime("%H:%M:%S")
        self.clock_label.config(text=f"Current Time: {current_time} ({self.timezone_str})")
        # Update clock every 1000ms (1 second)
        self.after(1000, self.update_clock)
        
    def create_header_frame(self):
        header_frame = tk.Frame(self.main_container, bg="#333333")
        header_frame.grid(row=1, column=0, sticky="ew")  # Stick to edges, no padding
        
        # Configure header frame to expand horizontally
        header_frame.grid_columnconfigure(2, weight=1)
        
        # Previous year button
        prev_year_btn = tk.Button(header_frame, text="<<", bg="#555555", fg="white", 
                                 command=self.prev_year, borderwidth=0)
        prev_year_btn.grid(row=0, column=0, padx=0, pady=0)
        
        # Previous month button
        prev_month_btn = tk.Button(header_frame, text="<", bg="#555555", fg="white", 
                                  command=self.prev_month, borderwidth=0)
        prev_month_btn.grid(row=0, column=1, padx=0, pady=0)
        
        # Date display label
        self.date_label = tk.Label(header_frame, text="", font=("TkDefaultFont", 14), 
                                  bg="#333333", fg="white")
        self.date_label.grid(row=0, column=2, sticky="ew", padx=0, pady=0)
        
        # Next month button
        next_month_btn = tk.Button(header_frame, text=">", bg="#555555", fg="white", 
                                  command=self.next_month, borderwidth=0)
        next_month_btn.grid(row=0, column=3, padx=0, pady=0)
        
        # Next year button
        next_year_btn = tk.Button(header_frame, text=">>", bg="#555555", fg="white", 
                                 command=self.next_year, borderwidth=0)
        next_year_btn.grid(row=0, column=4, padx=0, pady=0)
        
    def create_calendar_frame(self):
        self.cal_frame = tk.Frame(self.main_container, bg="#333333")
        self.cal_frame.grid(row=2, column=0, sticky="nsew")  # Expand in all directions
        
        # Configure grid to expand
        for i in range(8):  # 8 columns (week number + 7 days)
            self.cal_frame.grid_columnconfigure(i, weight=1)
        for i in range(7):  # Up to 7 rows (header + 6 weeks max)
            self.cal_frame.grid_rowconfigure(i, weight=1)
        
    def get_week_number(self, year, month, day):
        """Get the ISO week number for a given date"""
        return date(year, month, day).isocalendar()[1]
        
    def update_calendar(self):
        # Clear previous calendar content
        for widget in self.cal_frame.winfo_children():
            widget.destroy()
        
        # Reset selection
        self.selected_day = None
        self.selected_frame = None
        
        # Update header
        month_name = calendar.month_name[self.current_month]
        self.date_label.config(text=f"{month_name} {self.current_year}")
        
        # Get calendar data
        cal = calendar.monthcalendar(self.current_year, self.current_month)
        
        # Display week number header
        week_header = tk.Label(self.cal_frame, text="w|", font=("TkDefaultFont", 12, "bold"),
                              bg="#333333", fg="#aaaaaa")
        week_header.grid(row=0, column=0, sticky="nsew", padx=0, pady=0)
        
        # Display weekday headers (Monday first)
        weekdays = ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
        for i, day in enumerate(weekdays):
            wday_label = tk.Label(self.cal_frame, text=day, font=("TkDefaultFont", 12, "bold"),
                                bg="#333333", fg="#aaaaaa")
            wday_label.grid(row=0, column=i+1, sticky="nsew", padx=0, pady=0)
        
        # Display calendar days with week numbers
        for row_idx, week in enumerate(cal):
            # Get the first day of the week that's not zero
            first_day_of_week = next((day for day in week if day != 0), None)
            
            if first_day_of_week:
                # Calculate the week number
                week_num = self.get_week_number(self.current_year, self.current_month, first_day_of_week)
                
                # Display week number
                week_label = tk.Label(self.cal_frame, text=f"{week_num}|", font=("TkDefaultFont", 12),
                                    bg="#333333", fg="#aaaaaa")
                week_label.grid(row=row_idx+1, column=0, sticky="nsew", padx=0, pady=0)
            
            for col_idx, day in enumerate(week):
                if day != 0:
                    # Create a frame for each day to allow better styling
                    is_today = (day == self.today.day and 
                               self.current_month == self.today.month and 
                               self.current_year == self.today.year)
                    
                    is_weekend = (col_idx == 5 or col_idx == 6)  # Saturday (Sa) or Sunday (Su)
                    
                    bg_color = "#555555" if is_today else "#333333"
                    fg_color = "#ffffff" if is_today else "#ff9999" if is_weekend else "white"
                    
                    day_frame = tk.Frame(self.cal_frame, bg=bg_color)
                    day_frame.grid(row=row_idx+1, column=col_idx+1, sticky="nsew", padx=0, pady=0)
                    
                    # Display the day number
                    day_label = tk.Label(day_frame, text=f"{day:2d}", font=("TkDefaultFont", 12),
                                       bg=bg_color, fg=fg_color)
                    day_label.place(relx=0.5, rely=0.5, anchor="center")
                    
                    # Bind click events to the day frame and label
                    day_frame.bind("<Button-1>", lambda e, d=day, f=day_frame: self.select_day(d, f))
                    day_label.bind("<Button-1>", lambda e, d=day, f=day_frame: self.select_day(d, f))
        
        # Update the layout
        self.cal_frame.update_idletasks()
        self.update_idletasks()
        
    def select_day(self, day, frame):
        """Handle day selection with highlighting"""
        # If there was a previously selected day, reset its color
        if self.selected_frame and self.selected_frame != frame:
            # Get the original background color
            is_today = (self.selected_day == self.today.day and 
                       self.current_month == self.today.month and 
                       self.current_year == self.today.year)
            
            orig_bg = "#555555" if is_today else "#333333"
            self.selected_frame.configure(bg=orig_bg)
            
            # Also update the child label
            for child in self.selected_frame.winfo_children():
                if isinstance(child, tk.Label):
                    child.configure(bg=orig_bg)
        
        # If clicking the same day, toggle selection
        if self.selected_frame == frame:
            # Get the original background color
            is_today = (day == self.today.day and 
                       self.current_month == self.today.month and 
                       self.current_year == self.today.year)
            
            orig_bg = "#555555" if is_today else "#333333"
            frame.configure(bg=orig_bg)
            
            # Also update the child label
            for child in frame.winfo_children():
                if isinstance(child, tk.Label):
                    child.configure(bg=orig_bg)
                    
            self.selected_day = None
            self.selected_frame = None
        else:
            # Highlight the new selection
            frame.configure(bg="#007acc")  # Blue highlight color
            
            # Also update the child label
            for child in frame.winfo_children():
                if isinstance(child, tk.Label):
                    child.configure(bg="#007acc")
                    
            self.selected_day = day
            self.selected_frame = frame
        
    def prev_month(self):
        self.current_month -= 1
        if self.current_month < 1:
            self.current_month = 12
            self.current_year -= 1
        self.update_calendar()
        
    def next_month(self):
        self.current_month += 1
        if self.current_month > 12:
            self.current_month = 1
            self.current_year += 1
        self.update_calendar()
        
    def prev_year(self):
        self.current_year -= 1
        self.update_calendar()
        
    def next_year(self):
        self.current_year += 1
        self.update_calendar()
        
if __name__ == "__main__":
    app = SimpleCalendar()
    
    # Center window on screen
    app.update_idletasks()
    width = app.winfo_width()
    height = app.winfo_height()
    x = (app.winfo_screenwidth() // 2) - (width // 2)
    y = (app.winfo_screenheight() // 2) - (height // 2)
    app.geometry('{}x{}+{}+{}'.format(width, height, x, y))
    
    app.mainloop()
