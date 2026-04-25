/*
 * Copyright (c) 2026 Node_A7
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_tocad_irrigation (
    input  wire [7:0] ui_in,    // 0-6: Soil, 7: Rain
    output wire [7:0] uo_out,   // 0-6: Valves, 7: Status LED
    input  wire [7:0] uio_in,   // 0: DFT, 1-3: Freq, 4-6: Dur
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input  wire       ena,
    input  wire       clk,      // 10kHz
    input  wire       rst_n
);

    // Tie off unused bidirectionals
    assign uio_out = 8'b0;
    assign uio_oe  = 8'b0;

    // Signal Mapping
    wire [6:0] soil     = ui_in[6:0];
    wire       rain     = ui_in[7];
    wire       test_btn = uio_in[0];
    wire [2:0] freq_sel = uio_in[3:1];
    wire [2:0] dur_sel  = uio_in[6:4];

    // Prescaler: 10kHz to 1Hz/4Hz
    reg [13:0] prescaler;
    wire tick_1hz = (prescaler == 14'd9999);
    wire tick_4hz = (prescaler == 14'd2499) || (prescaler == 14'd4999) || 
                    (prescaler == 14'd7499) || (prescaler == 14'd9999);
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) prescaler <= 14'd0;
        else prescaler <= tick_1hz ? 14'd0 : prescaler + 14'd1;
    end

    // Heartbeat Signals
    reg clk_1hz_sig, clk_4hz_sig;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            clk_1hz_sig <= 1'b0;
            clk_4hz_sig <= 1'b0;
        end else begin
            if (tick_1hz) clk_1hz_sig <= ~clk_1hz_sig;
            if (tick_4hz) clk_4hz_sig <= ~clk_4hz_sig;
        end
    end

    // Frequency ROM (Simulation: 5s, Silicon: 30min+)
    reg [15:0] freq_val;
    always @(*) begin
        case (freq_sel)
            3'd0: freq_val = 16'd5; // SIMULATION VALUE - Change to 1800 for tapeout
            3'd1: freq_val = 16'd3600;
            3'd2: freq_val = 16'd7200;
            3'd3: freq_val = 16'd10800;
            3'd4: freq_val = 16'd14400;
            3'd5: freq_val = 16'd21600;
            3'd6: freq_val = 16'd28800;
            3'd7: freq_val = 16'd43200;
        endcase
    end

    // Duration ROM
    reg [6:0] dur_val_rom;
    always @(*) begin
        case (dur_sel)
            3'd0: dur_val_rom = 7'd10;
            3'd1: dur_val_rom = 7'd20;
            3'd2: dur_val_rom = 7'd30;
            3'd3: dur_val_rom = 7'd40;
            3'd4: dur_val_rom = 7'd50;
            3'd5: dur_val_rom = 7'd60;
            3'd6: dur_val_rom = 7'd90;
            3'd7: dur_val_rom = 7'd120;
        endcase
    end
    wire [6:0] dur_val = test_btn ? 7'd5 : dur_val_rom;

    // Interval Logic
    reg [15:0] interval_cnt;
    wire time_tick_base = (interval_cnt >= freq_val);
    wire time_tick      = time_tick_base || test_btn;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) interval_cnt <= 16'd0;
        else if (time_tick_base) interval_cnt <= 16'd0;
        else if (tick_1hz) interval_cnt <= interval_cnt + 16'd1;
    end

    // Fault Detection
    reg [1:0] streak_cnt [6:0];
    reg [6:0] fault_flag;
    genvar f;
    generate
        for (f = 0; f < 7; f = f + 1) begin : fault_detect
            always @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    streak_cnt[f] <= 2'd0;
                    fault_flag[f] <= 1'b0;
                end else if (time_tick_base) begin
                    if (!soil[f]) streak_cnt[f] <= 2'd0;
                    else if (streak_cnt[f] == 2'd2) fault_flag[f] <= 1'b1;
                    else streak_cnt[f] <= streak_cnt[f] + 2'd1;
                end
            end
        end
    endgenerate
    wire any_fault = |fault_flag;
    assign uo_out[7] = any_fault ? clk_4hz_sig : clk_1hz_sig;

    // Arbiter and Retry
    reg [6:0] valve_out;
    wire [2:0] active_count = valve_out[0] + valve_out[1] + valve_out[2] + valve_out[3] + valve_out[4] + valve_out[5] + valve_out[6];
    reg [2:0] active_prev;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) active_prev <= 3'd0;
        else active_prev <= active_count;
    end
    wire retry_tick = (active_count < active_prev);
    wire zone_tick  = time_tick || retry_tick;

    reg [6:0] grant;
    reg [2:0] slots_avail;
    integer j;
    always @(*) begin
        slots_avail = (active_count >= 3'd4) ? 3'd0 : (3'd4 - active_count);
        for (j = 0; j < 7; j = j + 1) begin
            if (zone_tick && soil[j] && !rain && !fault_flag[j] && !valve_out[j] && (slots_avail > 0)) begin
                grant[j] = 1'b1;
                slots_avail = slots_avail - 3'd1;
            end else grant[j] = 1'b0;
        end
    end

    // Zone FSMs
    reg [6:0] dur_cnt [6:0];
    reg [6:0] latched_dur [6:0];
    genvar z;
    generate
        for (z = 0; z < 7; z = z + 1) begin : zones
            wire start_water = grant[z];
            wire stop_water  = (dur_cnt[z] >= latched_dur[z]) && valve_out[z];

            always @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    valve_out[z] <= 1'b0;
                    dur_cnt[z] <= 7'd0;
                    latched_dur[z] <= 7'd0;
                end else begin
                    if (start_water && !valve_out[z]) begin
                        valve_out[z] <= 1'b1;
                        latched_dur[z] <= dur_val;
                        dur_cnt[z] <= 7'd0;
                    end else if (stop_water) begin
                        valve_out[z] <= 1'b0;
                        latched_dur[z] <= 7'd0;
                    end else if (valve_out[z] && tick_1hz) begin
                        dur_cnt[z] <= dur_cnt[z] + 7'd1;
                    end
                end
            end
            assign uo_out[z] = valve_out[z];
        end
    endgenerate
endmodule
