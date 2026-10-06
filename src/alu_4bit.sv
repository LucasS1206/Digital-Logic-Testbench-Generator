module alu_4bit (              
    input  logic [3:0] a,    
    input  logic [3:0] b,
    input  logic [2:0] opcode,
    output logic [3:0] result,
    output logic       zero, 
    output logic       carry,
    output logic       negative,
    output logic       overflow
);
   
    logic [4:0] ext_result;
    
    
    always_comb begin
        ext_result = 5'b0;
        overflow   = 1'b0; 

        
        case (opcode)
            3'b000: begin 
                ext_result = a + b;
                
                overflow = (a[3] == b[3]) && (ext_result[3] != a[3]);
            end
            
            3'b001: begin // SUB (a - b)
                ext_result = a - b;
                
                overflow = (a[3] != b[3]) && (ext_result[3] == b[3]);
            end
            
            3'b010: ext_result = {1'b0, a & b}; // AND
            3'b011: ext_result = {1'b0, a | b}; // OR
            3'b100: ext_result = {1'b0, a ^ b}; // XOR
            default: ext_result = 5'b0; 
        endcase

        result   = ext_result[3:0]; 
        carry    = ext_result[4]; 
        zero     = (result == 4'b0); 
        negative = result[3]; 
    end 
endmodule