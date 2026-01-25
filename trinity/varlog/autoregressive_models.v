// ═══════════════════════════════════════════════════════════════════════════════
// TRINITY FPGA - autoregressive_models v4.9.2
// ═══════════════════════════════════════════════════════════════════════════════
// Generated from .vibee specification
// Sacred Formula: φ² + 1/φ² = 3
// DO NOT EDIT - Auto-generated
// ═══════════════════════════════════════════════════════════════════════════════

`timescale 1ns / 1ps

module autoregressive_models (
  input  wire        clk,
  input  wire        rst_n,
  input  wire        enable,
  input  wire [63:0] ARConfig_order_in,
  output reg  [63:0] ARConfig_order_out,
  input  wire  ARConfig_include_intercept_in,
  output reg   ARConfig_include_intercept_out,
  input  wire [63:0] ARIMAConfig_p_in,
  output reg  [63:0] ARIMAConfig_p_out,
  input  wire [63:0] ARIMAConfig_d_in,
  output reg  [63:0] ARIMAConfig_d_out,
  input  wire [63:0] ARIMAConfig_q_in,
  output reg  [63:0] ARIMAConfig_q_out,
  input  wire  ARIMAConfig_seasonal_in,
  output reg   ARIMAConfig_seasonal_out,
  input  wire [63:0] DeepARConfig_hidden_size_in,
  output reg  [63:0] DeepARConfig_hidden_size_out,
  input  wire [63:0] DeepARConfig_num_layers_in,
  output reg  [63:0] DeepARConfig_num_layers_out,
  input  wire [255:0] DeepARConfig_distribution_in,
  output reg  [255:0] DeepARConfig_distribution_out,
  input  wire [31:0] ARCoefficients_phi_in,
  output reg  [31:0] ARCoefficients_phi_out,
  input  wire [63:0] ARCoefficients_intercept_in,
  output reg  [63:0] ARCoefficients_intercept_out,
  input  wire [31:0] MACoefficients_theta_in,
  output reg  [31:0] MACoefficients_theta_out,
  input  wire [31:0] DeepAROutput_mu_in,
  output reg  [31:0] DeepAROutput_mu_out,
  input  wire [31:0] DeepAROutput_sigma_in,
  output reg  [31:0] DeepAROutput_sigma_out,
  input  wire [31:0] DeepAROutput_samples_in,
  output reg  [31:0] DeepAROutput_samples_out,
  input  wire [255:0] LikelihoodParams_distribution_in,
  output reg  [255:0] LikelihoodParams_distribution_out,
  input  wire [31:0] LikelihoodParams_params_in,
  output reg  [31:0] LikelihoodParams_params_out,
  input  wire [31:0] ProbabilisticForecast_samples_in,
  output reg  [31:0] ProbabilisticForecast_samples_out,
  input  wire [31:0] ProbabilisticForecast_mean_in,
  output reg  [31:0] ProbabilisticForecast_mean_out,
  input  wire [31:0] ProbabilisticForecast_std_in,
  output reg  [31:0] ProbabilisticForecast_std_out,
  output reg         done
);

  // Sacred constants (φ² + 1/φ² = 3)
  localparam [31:0] PHI = 32'd1618033;      // φ × 10^6
  localparam [31:0] PHI_INV = 32'd618033;   // 1/φ × 10^6
  localparam [31:0] TRINITY = 32'd3;        // φ² + 1/φ² = 3
  localparam [31:0] PHOENIX = 32'd999;      // Sacred number

  // State machine
  localparam IDLE = 2'b00, PROCESS = 2'b01, DONE = 2'b10;
  reg [1:0] state;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 1'b0;
      ARConfig_order_out <= 64'd0;
      ARConfig_include_intercept_out <= 1'b0;
      ARIMAConfig_p_out <= 64'd0;
      ARIMAConfig_d_out <= 64'd0;
      ARIMAConfig_q_out <= 64'd0;
      ARIMAConfig_seasonal_out <= 1'b0;
      DeepARConfig_hidden_size_out <= 64'd0;
      DeepARConfig_num_layers_out <= 64'd0;
      DeepARConfig_distribution_out <= 256'd0;
      ARCoefficients_phi_out <= 32'd0;
      ARCoefficients_intercept_out <= 64'd0;
      MACoefficients_theta_out <= 32'd0;
      DeepAROutput_mu_out <= 32'd0;
      DeepAROutput_sigma_out <= 32'd0;
      DeepAROutput_samples_out <= 32'd0;
      LikelihoodParams_distribution_out <= 256'd0;
      LikelihoodParams_params_out <= 32'd0;
      ProbabilisticForecast_samples_out <= 32'd0;
      ProbabilisticForecast_mean_out <= 32'd0;
      ProbabilisticForecast_std_out <= 32'd0;
    end else begin
      case (state)
        IDLE: if (enable) begin
          state <= PROCESS;
          done <= 1'b0;
        end

        PROCESS: begin
          ARConfig_order_out <= ARConfig_order_in;
          ARConfig_include_intercept_out <= ARConfig_include_intercept_in;
          ARIMAConfig_p_out <= ARIMAConfig_p_in;
          ARIMAConfig_d_out <= ARIMAConfig_d_in;
          ARIMAConfig_q_out <= ARIMAConfig_q_in;
          ARIMAConfig_seasonal_out <= ARIMAConfig_seasonal_in;
          DeepARConfig_hidden_size_out <= DeepARConfig_hidden_size_in;
          DeepARConfig_num_layers_out <= DeepARConfig_num_layers_in;
          DeepARConfig_distribution_out <= DeepARConfig_distribution_in;
          ARCoefficients_phi_out <= ARCoefficients_phi_in;
          ARCoefficients_intercept_out <= ARCoefficients_intercept_in;
          MACoefficients_theta_out <= MACoefficients_theta_in;
          DeepAROutput_mu_out <= DeepAROutput_mu_in;
          DeepAROutput_sigma_out <= DeepAROutput_sigma_in;
          DeepAROutput_samples_out <= DeepAROutput_samples_in;
          LikelihoodParams_distribution_out <= LikelihoodParams_distribution_in;
          LikelihoodParams_params_out <= LikelihoodParams_params_in;
          ProbabilisticForecast_samples_out <= ProbabilisticForecast_samples_in;
          ProbabilisticForecast_mean_out <= ProbabilisticForecast_mean_in;
          ProbabilisticForecast_std_out <= ProbabilisticForecast_std_in;
          state <= DONE;
        end

        DONE: begin
          done <= 1'b1;
          state <= IDLE;
        end
      endcase
    end
  end

  // Behaviors:
  // - fit_ar
  // - fit_arima
  // - ar_forecast
  // - deepar_forward
  // - sample_forecast
  // - negative_log_likelihood
  // - difference_series
  // - inverse_difference

endmodule
