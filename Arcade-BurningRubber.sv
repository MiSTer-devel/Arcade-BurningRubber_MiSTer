//============================================================================
//  Arcade: Burning Rubber
//
//  Port to MiSTer
//  Copyright (C) 2017 Sorgelig
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//============================================================================

module emu
(
	`include "sys/emu_ports.vh"
);

///////// Default values for ports not used in this core /////////

assign ADC_BUS  = 'Z;
assign USER_OUT = '1;
assign {UART_RTS, UART_TXD, UART_DTR} = 0;
assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;
assign {SDRAM_DQ, SDRAM_A, SDRAM_BA, SDRAM_CLK, SDRAM_CKE, SDRAM_DQML, SDRAM_DQMH, SDRAM_nWE, SDRAM_nCAS, SDRAM_nRAS, SDRAM_nCS} = 'Z;
assign VGA_F1 = 0;
assign VGA_SCALER = 0;
assign VGA_DISABLE = 0;
assign HDMI_FREEZE = 0;
assign FB_FORCE_BLANK = 0;
assign HDMI_BLACKOUT = 0;
assign HDMI_BOB_DEINT = 0;

assign AUDIO_S = 0;
assign AUDIO_MIX = 0;

assign LED_USER  = ioctl_download;
assign LED_DISK = 0;
assign LED_POWER = 0;
assign BUTTONS = 0;

//////////////////////////////////////////////////////////////////

wire [1:0] ar = status[20:19];

assign VIDEO_ARX = (!ar) ? ((status[2])  ? 12'd1024 : 12'd939) : (ar - 1'd1);
assign VIDEO_ARY = (!ar) ? ((status[2])  ? 12'd939 :  12'd1024) : 12'd0;

// Used status bits
// 00000000001111111111222222222233
// 01234567890123456789012345678901
// 0123456789abcdefghijklmnopqrstuv
//   xxxx             xxxxx         

`include "build_id.v" 
localparam CONF_STR = {
	"A.BRUBBR;;",
	"H0OJK,Aspect ratio,Original,Full Screen,[ARC1],[ARC2];",
	"H0O2,Orientation,Vert,Horz;",
	"O1,Flip,Off,On;",
	"O35,Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%,CRT 75%;",
	"h1ON,Autosave Hiscores,Off,On;",
	"-;",
	"DIP;",
	"-;",
	"P1,Pause options;",
	"P1OL,Pause when OSD is open,On,Off;",
	"P1OM,Dim video after 10s,On,Off;",
	"-;",
	"R0,Reset;",
	"J1,Fire,Start 1P,Start 2P,Coin,Pause;",
	"jn,A,Start,Select,R;",
	"V,v",`BUILD_DATE
};

////////////////////   CLOCKS   ///////////////////

wire clk_sys, clk_24,clk_48;
wire pll_locked;

pll pll
(
	.refclk(CLK_50M),
	.rst(0),
	.outclk_0(clk_sys),
	.outclk_1(clk_24),
	.outclk_2(clk_48),
	.locked(pll_locked)
);

///////////////////////////////////////////////////

wire [31:0] status;
wire  [1:0] buttons;
wire        forced_scandoubler;
wire        direct_video;


wire        ioctl_download;
wire        ioctl_upload;
wire        ioctl_upload_req;
wire        ioctl_wr;
wire [24:0] ioctl_addr;
wire  [7:0] ioctl_dout;
wire  [7:0] ioctl_din;
wire  [7:0] ioctl_index;


wire [15:0] joystick_0, joystick_1;
wire [15:0] joy = joystick_0 | joystick_1;

wire [21:0] gamma_bus;

// DIP switches
reg [7:0] dsw[2];
always @(posedge clk_sys) if (ioctl_wr && (ioctl_index==254) && !ioctl_addr[24:1]) dsw[ioctl_addr[0]] <= ioctl_dout;

// HISCORE SYSTEM
// --------------

wire [10:0]hs_address;
wire [7:0] hs_data_in;
wire [7:0] hs_data_out;
wire hs_write_enable;
wire hs_write_intent;
wire hs_read_intent;
wire hs_pause;
wire hs_configured;

hiscore #(
	.HS_ADDRESSWIDTH(11),
	.HS_SCOREWIDTH(10),			// 624 bytes total
	.HS_CONFIGINDEX(5),
	.HS_DUMPINDEX(6),
	.CFG_ADDRESSWIDTH(2),		// 3 config lines
	.CFG_LENGTHWIDTH(2)     // 620 bytes in the biggest section
) hi (
	.*,
	.clk(clk_sys),
	.paused(pause_cpu),
	.autosave(status[23]),
	.ram_address(hs_address),
	.data_from_ram(hs_data_out),
	.data_to_ram(hs_data_in),
	.data_from_hps(ioctl_dout),
	.data_to_hps(ioctl_din),
	.ram_write(hs_write_enable),
	.ram_intent_read(hs_read_intent),
	.ram_intent_write(hs_write_intent),
	.pause_cpu(hs_pause),
	.configured(hs_configured)
);

hps_io #(.CONF_STR(CONF_STR)) hps_io
(
	.clk_sys(clk_sys),
	.HPS_BUS(HPS_BUS),

	.buttons(buttons),
	.status(status),
	.status_menumask({hs_configured,direct_video}),
	.forced_scandoubler(forced_scandoubler),
	.gamma_bus(gamma_bus),
	.direct_video(direct_video),
	.video_rotated(video_rotated),

	.ioctl_download(ioctl_download),
	.ioctl_upload(ioctl_upload),
	.ioctl_upload_req(ioctl_upload_req),
	.ioctl_wr(ioctl_wr),
	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_dout),
	.ioctl_din(ioctl_din),
	.ioctl_index(ioctl_index),

	.joystick_0(joystick_0),
	.joystick_1(joystick_1)
);

wire m_up     = joy[3];
wire m_down   = joy[2];
wire m_left   = joy[1];
wire m_right  = joy[0];
wire m_fire   = joy[4];

wire m_up_2   = joy[3];
wire m_down_2 = joy[2];
wire m_left_2 = joy[1];
wire m_right_2= joy[0];
wire m_fire_2 = joy[4];

wire m_start1 = joy[5];
wire m_start2 = joy[6];
wire m_coin_1 = joystick_0[7];
wire m_coin_2 = joystick_1[7];
wire m_pause  = joy[8];

// PAUSE SYSTEM
wire pause_cpu;

wire [7:0] rgb_out;

wire reset = RESET | status[0] |  buttons[1] | ioctl_download;

pause #(3,3,2,12) pause (
  .*,
  .reset(reset),
  .user_button(m_pause),
  .pause_request(hs_pause),
  .options(~status[22:21])
);

wire hblank, vblank;
wire ce_vid;
wire hs, vs;
wire [2:0] r,g;
wire [1:0] b;

wire no_rotate = status[2] | direct_video;
wire rotate_ccw = 0;
wire core_flip = status[1];
wire flip = 0;
wire video_rotated;

screen_rotate screen_rotate (.*);

arcade_video #(253,8) arcade_video
(
	.*,

	.clk_video(clk_48),
	.ce_pix(ce_vid),

	.RGB_in(rgb_out),
	.HBlank(hblank),
	.VBlank(vblank),
	.HSync(hs),
	.VSync(vs),

	.fx(status[5:3])
);


wire [10:0] audio;
assign AUDIO_L = {audio, 5'b00000};
assign AUDIO_R = AUDIO_L;
assign AUDIO_S = 0;

burnin_rubber burnin_rubber
(
	.clock_12(clk_sys),
	.reset(reset),

	.dn_addr(ioctl_addr[16:0]),
	.dn_data(ioctl_dout),
	.dn_wr(ioctl_wr && (ioctl_index==0)),

	.video_ce(ce_vid),
	.video_r(r),
	.video_g(g),
	.video_b(b),

	.video_hs(hs),
	.video_vs(vs),
	.video_vblank(vblank),
	.video_hblank(hblank),

	.audio_out(audio),
	.flip(core_flip),
	.start2(m_start2),
	.start1(m_start1),
	.coin1(m_coin_1),
	.coin2(m_coin_2),

	.fire1(m_fire),
	.right1(m_right),
	.left1(m_left),
	.down1(m_down),
	.up1(m_up),

	.fire2(m_fire_2),
	.right2(m_right_2),
	.left2(m_left_2),
	.down2(m_down_2),
	.up2(m_up_2),
	
	.dip_sw1(~dsw[0]),
	.dip_sw2(~(dsw[1] & 8'h1f)),

  .paused(pause_cpu),

  .hs_data_out(hs_data_out),
  .hs_data_in(hs_data_in),
  .hs_write_enable(hs_write_enable),
  .hs_write_intent(hs_write_intent),
  .hs_read_intent(hs_read_intent),
  .hs_address(hs_address)
);

endmodule
