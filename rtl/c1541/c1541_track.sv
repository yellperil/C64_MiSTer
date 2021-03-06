// 
// c1541_track
// Copyright (c) 2016 Sorgelig
//
// This source file is free software: you can redistribute it and/or modify
// it under the terms of the Lesser GNU General Public License as published
// by the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This source file is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.
//
//
/////////////////////////////////////////////////////////////////////////

module c1541_track
(
	input         clk,
	input         reset,

	output [31:0] sd_lba,
	output  [5:0] sd_sz,
	output reg    sd_rd,
	output reg    sd_wr,
	input         sd_ack,

	input         save_track,
	input         change,
	input   [5:0] track,
	output reg    busy
);

assign sd_lba = lba;
assign sd_sz  = len[5:0];

wire [5:0] track_s;
wire       change_s, save_track_s, reset_s;

c1541_sync #(6) track_sync  (clk, track,      track_s);
c1541_sync #(1) change_sync (clk, change,     change_s);
c1541_sync #(1) save_sync   (clk, save_track, save_track_s);
c1541_sync #(1) reset_sync  (clk, reset,      reset_s);

wire [9:0] start_sectors[41] =
'{  0, 21, 42, 63, 84,105,126,147,168,189,210,231,252,273,294,315,336,357,376,395,
  414,433,452,471,490,508,526,544,562,580,598,615,632,649,666,683,700,717,734,751,
  768
};

reg [31:0] lba;
reg  [9:0] len;

always @(posedge clk) begin
	reg  [5:0] cur_track = 0;
	reg        old_change, update = 0;
	reg        saving = 0, initing = 0;
	reg        old_save_track = 0;
	reg        old_ack;
	reg  [5:0] track_new;

	// delay track change after sync, so make sure save_track comes first.
	track_new <= track_s ? (track_s - 1'd1) : 6'd0;

	old_change <= change_s;
	if(~old_change & change_s) update <= 1;
	
	old_ack <= sd_ack;
	if(sd_ack) {sd_rd,sd_wr} <= 0;

	if(reset_s) begin
		cur_track <= '1;
		busy      <= 0;
		sd_rd     <= 0;
		sd_wr     <= 0;
		saving    <= 0;
		update    <= 1;
	end
	else
	if(busy) begin
		if(old_ack && ~sd_ack) begin
			if((initing || saving) && (cur_track != track_new)) begin
				saving    <= 0;
				initing   <= 0;
				cur_track <= track_new;
				len       <= start_sectors[track_new+1'd1] - start_sectors[track_new] - 1'd1;
				lba       <= start_sectors[track_new];
				sd_rd     <= 1;
			end
			else begin
				busy      <= 0;
			end
		end
	end
	else begin
		old_save_track <= save_track_s;
		if((old_save_track ^ save_track_s) && ~&cur_track[5:1]) begin
			saving    <= 1;
			len       <= start_sectors[cur_track+1'd1] - start_sectors[cur_track] - 1'd1;
			lba       <= start_sectors[cur_track];
			sd_wr     <= 1;
			busy      <= 1;
		end
		else if(update) begin
			update    <= 0;
			initing   <= 1;
			cur_track <= 17;
			len       <= start_sectors[17+1] - start_sectors[17] - 1'd1;
			lba       <= start_sectors[17];
			sd_rd     <= 1;
			busy      <= 1;
		end
		else if(cur_track != track_new) begin
			cur_track <= track_new;
			len       <= start_sectors[track_new+1'd1] - start_sectors[track_new] - 1'd1;
			lba       <= start_sectors[track_new];
			sd_rd     <= 1;
			busy      <= 1;
		end
	end
end

endmodule
