module encoder_8to3 (
    input  logic [7:0] d,
    output logic [2:0] y,
    output logic       valid
);
    always_comb begin
        valid = 1'b1;
        if      (d[7]) y = 3'd7; 
        else if (d[6]) y = 3'd6; 
        else if (d[5]) y = 3'd5;
        else if (d[4]) y = 3'd4;
        else if (d[3]) y = 3'd3;
        else if (d[2]) y = 3'd2;
        else if (d[1]) y = 3'd1;
        else if (d[0]) y = 3'd0;
        else begin 
            y = 3'd0; 
            valid = 1'b0; 
        end
    end
endmodule