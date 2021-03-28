/*  This file is part of JT8255.
    JT8255 program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JT8255 program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JT8255.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 28-3-2021 */

module jt8255(
    input               rst,
    input               clk,

    // CPU interface
    input       [1:0]   addr,
    input       [7:0]   din,
    output reg  [7:0]   dout,
    input               rdn,
    input               wrn,
    input               csn,

    // External pins to peripherals
    input       [7:0]   porta_din,
    input       [7:0]   portb_din,
    input       [7:0]   portc_din,

    output reg  [7:0]   porta_dout,
    output reg  [7:0]   portb_dout,
    output      [7:0]   portc_dout
);

localparam ISINA=4, ISINB=1, ISINCL=0, ISINCH=3; // Control word bits
localparam INTRA=3, OBFA=7, ACKA=6, STBA=4, IBFA=5, // PC bits, mode 2
           INTRB=0, OBFB=1, ACKB=2, STBB=2, IBFB=1;

localparam INTEA=4, INTEB=2;

reg  [6:0] ctrl;
reg  [7:0] latch_a, latch_b, latch_c;

wire       mode_b,
           isin_a, isin_b, isin_cl, isin_ch; // is input a,b,c...
wire [1:0] mode_a;

wire       write, read;
reg        last_write, last_read;

reg        inte_a, inte_b;

wire       acka, ackb, stba, stbb;

assign read   = !rdn && !csn;
assign write  = !wrn && !csn;
assign mode_b = ctrl[2];
assign mode_a = ctrl[6:5];

assign isin_a  = ctrl[ISINA];
assign isin_b  = ctrl[ISINB];
assign isin_cl = ctrl[ISINCL];
assign isin_ch = ctrl[ISINCH];

assign acka    = portc_din[ACKA];
assign stba    = portc_din[STBA];
assign ackb    = portc_din[ACKB];
assign stbb    = portc_din[STBB]; // this is the same as ackb
assign last_stbb = last_ackb;

reg  last_acka, last_ackb, last_stba;
wire last_stbb;

// Mode control
always @(posedge clk, posedge rst) begin
    if( rst ) begin
        ctrl       <= 7'h1b;
        last_write <= 0;
        latch_a    <= 8'hff;
        latch_b    <= 8'hff;
        latch_c    <= 8'hff;
        last_acka  <= 0;
        last_ackb  <= 0;
        last_stba  <= 0;
        inte_a     <= 0;
        inte_b     <= 0;
    end else begin
        last_write <= write;
        last_acka  <= acka;
        last_ackb  <= ackb;
        last_stba  <= stba;

        if( !write && last_write ) begin
            case( addr )
                2'd0: begin // Port A
                    if( !isin_a ) begin
                        latch_a <= din; // A is an output
                        if( mode_a!=0 ) begin
                            latch_c[OBFA] <= 1;
                            if(inte_a) latch_c[INTRA] <= 0;  // interrupt pin
                        end
                    end
                end
                2'd1: begin // Port B
                    if( !isin_b ) begin
                        latch_b <= din; // B is an output
                        if( mode_b ) begin
                            latch_c[OBFB] <= 1;
                            if(inte_b) latch_c[INTRB] <= 0;  // interrupt pin
                        end
                    end                end
                2'd2: begin
                    case( {mode_a, mode_b} )
                        3'b00_0: begin
                            if(!isin_ch) latch_c[7:4] <= din[7:4];
                            if(!isin_cl) latch_c[3:0] <= din[3:0];
                        end
                        // Mode 1 for port B
                        3'b00_1: if(!isin_ch) latch_c[7:4] <= din[7:4];
                        // Mode 1 for port A
                        3'b01_0: if(!isin_cl) latch_c[3:0] <= din[3:0];
                        // Mode 2 for port A
                        3'b10_0: if(!isin_cl) latch_c[2:0] <= din[2:0];
                        default:; // ignore input
                    endcase
                end
                2'd3: begin
                    if( din[7] ) begin
                        ctrl <= din[6:0];
                        if( !din[ISINCL] ) latch_c[3:0] <= 0;
                        if( !din[ISINCH] ) latch_c[7:4] <= 0;
                        if( !din[ISINB]  ) latch_b <= 0;
                        if( !din[ISINA]  ) latch_a <= 0;
                    end else begin
                        latch_c[ din[3:1] ] <= din[0];
                        if( din[3:1]==INTEA ) inte_a <= din[0];
                        if( din[3:1]==INTEB ) inte_b <= din[0];
                    end
                end
            endcase
        end else begin
            // Input Buffer Full
            if( mode_b && !isin_b && stbb && !last_stbb )
                latch_c[IBFB] <= 1;
            if( mode_a!=0 && !isin_a && stba && !last_stba )
                latch_c[IBFA] <= 1;
            // clears the interrupts
            if(!inte_a) latch_c[INTRA] <= 0;
            if(!inte_b) latch_c[INTRB] <= 0;
            if( mode_a!=2'd00 ) begin
                // The peripheral reads
                if( !isin_a && acka && !last_acka ) begin
                    latch_c[INTRA] <= 0;
                    latch_c[OBFA]  <= 0;
                end
                // The CPU reads
                if( isin_a && read && !last_read && addr==2'd0 ) begin
                    latch_c[INTRA] <= 0;
                    latch_c[IBFA]  <= 0;
                end
            end
            if( mode_b ) begin
                // The peripheral reads
                if( !isin_b && ackb && !last_ackb ) begin
                    latch_c[INTRB] <= 0;
                    latch_c[OBFB]  <= 0;
                end
                // The CPU reads
                if( isin_b && read && !last_read && addr==2'd1 ) begin
                    latch_c[INTRB] <= 0;
                    latch_c[IBFB]  <= 0;
                end
            end
        end
    end
end

// CPU interface
always @(posedge clk, posedge rst) begin
    if( rst ) begin
        dout      <= 8'hff;
        last_read <= 0;
    end else begin
        last_read <= read;
        if( read ) begin
            case( addr )
                2'd0: dout <= isin_a ? porta_din : latch_a;
                2'd1: dout <= isin_b ? portb_din : latch_b;
                2'd2: begin // Port C output depends on the mode
                    dout[7:4] <= isin_ch ? portc_din[7:4] : latch_c[7:4];
                    dout[3:0] <= isin_cl ? portc_din[3:0] : latch_c[3:0];
                    // Special modes
                    if( mode_b )
                        dout[2:0] <= { ackb, latch_c[1:0] };
                    if( mode_a!=0 )
                        dout[5:3] <= { acka, latch_c[4:3] };
                    if( mode_a[1] )
                        dout[7:4] <= { latch_c[7], acka, latch_c[5], stba };
                end
                2'd3: dout <= { 1'b1, ctrl };
            endcase
        end
    end
end

// Output port registers
assign portc_dout = latch_c;

always @(posedge clk) begin
    porta_dout <= isin_a ? porta_din : latch_a;
    portb_dout <= isin_b ? portb_din : latch_b;
end

endmodule