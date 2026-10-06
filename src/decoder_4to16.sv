module decoder_4to16 (
    input  logic [3:0] sel, 
    input  logic       enable,
    output logic [15:0] y
);
    
    always_comb begin
        if (!enable) begin 
            y = 16'hFFFF;
        end else begin
           
            y = ~(16'h0001 << sel); 
        end
    end
endmodule