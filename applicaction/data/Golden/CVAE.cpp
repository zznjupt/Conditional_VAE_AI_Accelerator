//#include "systemc.h"
#include <bits/stdc++.h>

#define SIGMOID 0
#define TANH 1
#define MAX_LEN 60
#define QUAN 24
#define DATA_WIDTH 32
using namespace std;

// Define data type
// typedef sc_int<DATA_WIDTH> DT;
// typedef sc_int<DATA_WIDTH*2> DOUBLE_DT;
typedef int64_t DT;
typedef int64_t DOUBLE_DT;



DT cordic(DT in, int mode){
	const int CORDIC_QUAN = 16;
	int M = 3;
	int N = 15;
	int P = 18;
	DT M_ATANH[4];
	DT ATANH[16];
	DT z0;
	DT X[30];
	DT Y[30];
	DT Z[30];
		
	DT MX[30];
	DT MY[30];
	DT MZ[30];

	// Inv torque for (m, n) = (3, 15)
	DT inv_torque = 10754.6 * pow(2, CORDIC_QUAN);
	//cout << "INV_TORQUE: " << inv_torque;

	// arc-tanh LUT for k <= 0
	M_ATANH[0] = 386121;
	M_ATANH[1] = 204353;
	M_ATANH[2] = 112524;
	M_ATANH[3] = 63763;

	// arc-tanh LUT for k > 0
	ATANH[0] = 0; // not used
	ATANH[1] = 35999;
	ATANH[2] = 16738;
	ATANH[3] = 8235;
	ATANH[4] = 4101;
	ATANH[5] = 2048;
	ATANH[6] = 1024;
	ATANH[7] = 512;
	ATANH[8] = 256;
	ATANH[9] = 128;
	ATANH[10] = 64;
	ATANH[11] = 32;
	ATANH[12] = 16;
	ATANH[13] = 8;
	ATANH[14] = 4;
	ATANH[15] = 2;

	if(mode == SIGMOID) // D2 selection
		z0 = -in;
	else	
		z0 = in << 1;

	MX[0] = inv_torque;
	MY[0] = 0;
	MZ[0] = z0 ;

	for(int i = 0 ; i <= M ; i++){
		int k = -M+i;
		int shift = 1 << (1-k);
		//cout << "Shift: " << shift  << " " << k << endl;
		if(MZ[i] < 0) {
			MX[i+1] = MX[i] - (MY[i] - (MY[i] >> shift));
			MY[i+1] = MY[i] - (MX[i] - (MX[i] >> shift));
			MZ[i+1] = MZ[i] + M_ATANH[i];
		}   
		else{
			MX[i+1] = MX[i] + (MY[i] - (MY[i] >> shift));
			MY[i+1] = MY[i] + (MX[i] - (MX[i] >> shift));
			MZ[i+1] = MZ[i] - M_ATANH[i];
		}	
	}

	X[1] = MX[M+1];
	Y[1] = MY[M+1];
	Z[1] = MZ[M+1];


	for(int k = 1 ; k <= N ; k++){
		if(Z[k] < 0) {
			X[k+1] = X[k] - (Y[k] >> k);
			Y[k+1] = Y[k] - (X[k] >> k);
			Z[k+1] = Z[k] + ATANH[k];
		}   
		else{
			X[k+1] = X[k] + (Y[k] >> k);
			Y[k+1] = Y[k] + (X[k] >> k);
			Z[k+1] = Z[k] - ATANH[k];
		}	   
			
		if(k==4 || k==13){ // accumulate again if k equals to specific value
			DT tempX = X[k+1];
			DT tempY = Y[k+1];
			DT tempZ = Z[k+1];
			if(tempZ < 0) {
				X[k+1] = tempX - (tempY >> k);
				Y[k+1] = tempY - (tempX >> k);
				Z[k+1] = tempZ + ATANH[k];
			}   
			else{
				X[k+1] = tempX + (tempY >> k);
				Y[k+1] = tempY + (tempX >> k);
				Z[k+1] = tempZ - ATANH[k];
			}	
		}

	}
	int t = N;
	//printf("----------------------\n");
	// printf("MX0: %x\n", (int)X[t]);
	// printf("MY0: %x\n", (int)Y[t]);
	// printf("MZ0: %x\n", (int)Z[t]);
	// printf("MX1: %x\n", (int)X[t+1]);
	// printf("MY1: %x\n", (int)Y[t+1]);
	// printf("MZ1: %x\n", (int)Z[t+1]);
		
	X[0] = X[N+1] + Y[N+1] + (1 << CORDIC_QUAN);
	Y[0] = (1 << CORDIC_QUAN);
	Z[0] = 0;

	for(int k = 0 ; k < P ; k++) {
		if(Y[k] < 0) {
			X[k+1] = X[k];
			Y[k+1] = Y[k] + (X[k] >> k);
			Z[k+1] = Z[k] - ((1 << CORDIC_QUAN) >> k );
		}   
		else{
			X[k+1] = X[k];
			Y[k+1] = Y[k] - (X[k] >> k);
			Z[k+1] = Z[k] + ((1 << CORDIC_QUAN) >> k );
				
		}	   
	}


	DT result;
	if(mode == SIGMOID) {
		result = Z[18]; // result = S
	}
	else {
		result = (1 << CORDIC_QUAN) - (Z[18] << 1); // result = 1 - 2S
	}
		
	return result;
		

}
	




class CVAE {
private:
	// weights/bias in SRAM
	int32_t fc_l2h_weights[32*4];
	int32_t fc_l2h_bias[32];

	int32_t fc_conf_weights[2*38];
	int32_t fc_conf_bias[2];

	int32_t fc_state_weights[13*32];
	int32_t fc_state_bias[13];

	int32_t gru_ir_weights[32*19];
	int32_t gru_iz_weights[32*19];
	int32_t gru_in_weights[32*19];
	int32_t gru_hr_weights[32*32];
	int32_t gru_hz_weights[32*32];
	int32_t gru_hn_weights[32*32];

	int32_t gru_ir_bias[32];
	int32_t gru_iz_bias[32];
	int32_t gru_in_bias[32];
	int32_t gru_hr_bias[32];
	int32_t gru_hz_bias[32];
	int32_t gru_hn_bias[32];

	// Input in SRAM
	int32_t s_in[13];
	int32_t s_goal[6];
	int32_t z_in[4];

	// Output in SRAM
	int seq_lens;
	int32_t state_buffer[MAX_LEN][13];

	// Hidden 0 for GRU

	// Debug info
	int32_t hidden_buffer[MAX_LEN][32];
	int32_t conf_buffer[MAX_LEN][2];

	int32_t FC_IR_buffer[MAX_LEN][32];
	int32_t FC_IZ_buffer[MAX_LEN][32];
	int32_t FC_IN_buffer[MAX_LEN][32];
	int32_t FC_HR_buffer[MAX_LEN][32];
	int32_t FC_HZ_buffer[MAX_LEN][32];
	int32_t FC_HN_buffer[MAX_LEN][32];

	// current steps

public:
	CVAE();
	void load_1D_data(string, int32_t*, int);
	void load_all_data(void);
	void store_data(string, int32_t*, int);
	void store_all_data(void);
	void compute();
	void verify_result(void);

	void L2H_FC();
	void STATE_FC();
	void CONF_FC();
	void GRU();
	
};

//int sc_main(int argc,char** argv){
int main(int argc,char** argv){
	CVAE* model = new CVAE;
	
	model->load_all_data();
	model->compute();
	model->verify_result();

	model->store_all_data();

	delete model;
	return 0;
}

void CVAE::load_1D_data(string file_name, int32_t* arr, int row) {
	fstream file;
	double data;

	file.open(file_name.c_str(), ios::in);
	if (!file) {
		cout << "Failed to open file: " << file_name << endl;
		assert(false);
	}

	for (int i = 0; i < row; i++) {
		file >> data;
		arr[i] = data * pow(2, QUAN);
	}

	file.close();
}

CVAE::CVAE() {
	seq_lens = 0;
}

void CVAE::load_all_data(void) {
	load_1D_data("data/weights/fc_l2h_weights.csv", fc_l2h_weights, 32 * 4);
	load_1D_data("data/weights/fc_l2h_bias.csv", fc_l2h_bias, 32);

	load_1D_data("data/weights/fc_conf0_weights.csv", fc_conf_weights, 2 * 38);
	load_1D_data("data/weights/fc_conf0_bias.csv", fc_conf_bias, 2);

	load_1D_data("data/weights/fc_state0_weights.csv", fc_state_weights, 13 * 32);
	load_1D_data("data/weights/fc_state0_bias.csv", fc_state_bias, 13);

	load_1D_data("data/weights/gru_ir_weights.csv", gru_ir_weights, 32 * 19);
	load_1D_data("data/weights/gru_iz_weights.csv", gru_iz_weights, 32 * 19);
	load_1D_data("data/weights/gru_in_weights.csv", gru_in_weights, 32 * 19);
	load_1D_data("data/weights/gru_hr_weights.csv", gru_hr_weights, 32 * 32);
	load_1D_data("data/weights/gru_hz_weights.csv", gru_hz_weights, 32 * 32);
	load_1D_data("data/weights/gru_hn_weights.csv", gru_hn_weights, 32 * 32);

	load_1D_data("data/weights/gru_ir_bias.csv", gru_ir_bias, 32);
	load_1D_data("data/weights/gru_iz_bias.csv", gru_iz_bias, 32);
	load_1D_data("data/weights/gru_in_bias.csv", gru_in_bias, 32);
	load_1D_data("data/weights/gru_hr_bias.csv", gru_hr_bias, 32);
	load_1D_data("data/weights/gru_hz_bias.csv", gru_hz_bias, 32);
	load_1D_data("data/weights/gru_hn_bias.csv", gru_hn_bias, 32);

	// load_1D_data("data/inputs/s_in.csv", s_in, 13);
	// load_1D_data("data/inputs/s_goal.csv", s_goal, 6);
	// load_1D_data("data/inputs/z_in.csv", z_in, 4);
	load_1D_data("data/inputs/s_in_0.csv", s_in, 13);
	load_1D_data("data/inputs/s_goal_0.csv", s_goal, 6);
	load_1D_data("data/inputs/z_in_0.csv", z_in, 4);

}

void CVAE::store_data(string file_name, int32_t* arr , int len){
	fstream file;
	

	file.open(file_name.c_str(), ios::out);
	if (!file) {
		cout << "Failed to create file: " << file_name << endl;
		assert(false);
	}

	for (int i = 0; i < len; i++) {
		file <<  setw(8) << setfill('0') << hex << arr[i] << endl;
	}

	file.close();
}

void CVAE::store_all_data(void){
	store_data("../TP/weights/fc_l2h_weights.csv", fc_l2h_weights, 32 * 4);
	store_data("../TP/bias/fc_l2h_bias.csv", fc_l2h_bias, 32);

	store_data("../TP/weights/fc_conf0_weights.csv", fc_conf_weights, 2 * 38);
	store_data("../TP/bias/fc_conf0_bias.csv", fc_conf_bias, 2);

	store_data("../TP/weights/fc_state0_weights.csv", fc_state_weights, 13 * 32);
	store_data("../TP/bias/fc_state0_bias.csv", fc_state_bias, 13);

	store_data("../TP/weights/gru_ir_weights.csv", gru_ir_weights, 32 * 19);
	store_data("../TP/weights/gru_iz_weights.csv", gru_iz_weights, 32 * 19);
	store_data("../TP/weights/gru_in_weights.csv", gru_in_weights, 32 * 19);
	store_data("../TP/weights/gru_hr_weights.csv", gru_hr_weights, 32 * 32);
	store_data("../TP/weights/gru_hz_weights.csv", gru_hz_weights, 32 * 32);
	store_data("../TP/weights/gru_hn_weights.csv", gru_hn_weights, 32 * 32);

	store_data("../TP/bias/gru_ir_bias.csv", gru_ir_bias, 32);
	store_data("../TP/bias/gru_iz_bias.csv", gru_iz_bias, 32);
	store_data("../TP/bias/gru_in_bias.csv", gru_in_bias, 32);
	store_data("../TP/bias/gru_hr_bias.csv", gru_hr_bias, 32);
	store_data("../TP/bias/gru_hz_bias.csv", gru_hz_bias, 32);
	store_data("../TP/bias/gru_hn_bias.csv", gru_hn_bias, 32);

	store_data("../TP/inputs/s_in.csv", s_in, 13);
	store_data("../TP/inputs/s_goal.csv", s_goal, 6);
	store_data("../TP/inputs/z_in.csv", z_in, 4);

	fstream file;
	string file_name;

	file_name = "../TP/debug/hidden.csv";
	file.open(file_name.c_str(), ios::out);
	if (!file) {
		cout << "Failed to create file: " << file_name << endl;
		assert(false);
	}
	for (int i = 0; i < MAX_LEN; i++)
		for (int j = 0; j < 32; j++)
			file <<  setw(8) << setfill('0')<<  hex << hidden_buffer[i][j] << endl;
		
	file.close();

	
	file_name = "../TP/outputs/state.csv";
	file.open(file_name.c_str(), ios::out);
	if (!file) {
		cout << "Failed to create file: " << file_name << endl;
		assert(false);
	}
	for (int i = 0; i < MAX_LEN; i++)
		for (int j = 0; j < 13; j++)
			file <<  setw(8) << setfill('0')<<  hex << state_buffer[i][j] << endl;
		
	file.close();
	
	
	file_name = "../TP/debug/conf.csv";
	file.open(file_name.c_str(), ios::out);
	if (!file) {
		cout << "Failed to create file: " << file_name << endl;
		assert(false);
	}
	for (int i = 0; i < MAX_LEN; i++)
		for (int j = 0; j < 2; j++)
			file <<  setw(8) << setfill('0')<<  hex << conf_buffer[i][j] << endl;
		
	file.close();

	
	file_name = "../TP/debug/FC_HR.csv";
	file.open(file_name.c_str(), ios::out);
	if (!file) {
		cout << "Failed to create file: " << file_name << endl;
		assert(false);
	}
	for (int i = 0; i < MAX_LEN; i++)
		for (int j = 0; j < 32; j++)
			file <<  setw(8) << setfill('0')<<  hex << FC_HR_buffer[i][j] << endl;
	file.close();

	
	file_name = "../TP/debug/FC_HN.csv";
	file.open(file_name.c_str(), ios::out);
	if (!file) {
		cout << "Failed to create file: " << file_name << endl;
		assert(false);
	}
	for (int i = 0; i < MAX_LEN; i++)
		for (int j = 0; j < 32; j++)
			file <<  setw(8) << setfill('0')<<  hex << FC_HN_buffer[i][j] << endl;
	file.close();

	
	file_name = "../TP/debug/FC_HZ.csv";
	file.open(file_name.c_str(), ios::out);
	if (!file) {
		cout << "Failed to create file: " << file_name << endl;
		assert(false);
	}
	for (int i = 0; i < MAX_LEN; i++)
		for (int j = 0; j < 32; j++)
			file<<  setw(8) << setfill('0') << hex << FC_HZ_buffer[i][j] << endl;
	file.close();

	
	file_name = "../TP/debug/FC_IR.csv";
	file.open(file_name.c_str(), ios::out);
	if (!file) {
		cout << "Failed to create file: " << file_name << endl;
		assert(false);
	}
	for (int i = 0; i < MAX_LEN; i++)
		for (int j = 0; j < 32; j++)
			file <<  setw(8) << setfill('0') << hex <<  FC_IR_buffer[i][j] << endl;
	file.close();

	
	file_name = "../TP/debug/FC_IN.csv";
	file.open(file_name.c_str(), ios::out);
	if (!file) {
		cout << "Failed to create file: " << file_name << endl;
		assert(false);
	}
	for (int i = 0; i < MAX_LEN; i++)
		for (int j = 0; j < 32; j++)
			file <<  setw(8) << setfill('0') << hex <<  FC_IN_buffer[i][j] << endl;
	file.close();

	
	file_name = "../TP/debug/FC_IZ.csv";
	file.open(file_name.c_str(), ios::out);
	if (!file) {
		cout << "Failed to create file: " << file_name << endl;
		assert(false);
	}
	for (int i = 0; i < MAX_LEN; i++)
		for (int j = 0; j < 32; j++)
			file <<  setw(8) << setfill('0') << hex <<  FC_IZ_buffer[i][j] << endl;
	file.close();

	
	file_name = "../TP/outputs/seq_lens.csv";
	file.open(file_name.c_str(), ios::out);
	if (!file) {
		cout << "Failed to create file: " << file_name << endl;
		assert(false);
	}
	
	file << hex <<  seq_lens << endl;
	file.close();

	file_name = "../TP/weights/weights.csv";
	file.open(file_name.c_str(), ios::out);

	for (int i = 0; i < 32*19; i++) 
		file  <<  setw(8) << setfill('0') << hex << gru_in_weights[i] << endl;
	for (int i = 0; i < 32*19; i++) 
		file  <<  setw(8) << setfill('0') << hex << gru_ir_weights[i] << endl;
	for (int i = 0; i < 32*19; i++) 
		file  <<  setw(8) << setfill('0') << hex << gru_iz_weights[i] << endl;
		
	for (int i = 0; i < 32*32; i++) 
		file  <<  setw(8) << setfill('0') << hex << gru_hn_weights[i] << endl;
	for (int i = 0; i < 32*32; i++) 
		file  <<  setw(8) << setfill('0') << hex << gru_hr_weights[i] << endl;
	for (int i = 0; i < 32*32; i++) 
		file  <<  setw(8) << setfill('0') << hex << gru_hz_weights[i] << endl;

	for (int i = 0; i < 32*13; i++) 
		file  <<  setw(8) << setfill('0') << hex << fc_state_weights[i] << endl;
	for (int i = 0; i < 38*2; i++) 
		file  <<  setw(8) << setfill('0') << hex << fc_conf_weights[i] << endl;
	for (int i = 0; i < 32*4; i++) 
		file  <<  setw(8) << setfill('0') << hex << fc_l2h_weights[i] << endl;

	file.close();

	
	file_name = "../TP/bias/bias.csv";
	file.open(file_name.c_str(), ios::out);

	for (int i = 0; i < 32; i++) 
		file  <<  setw(8) << setfill('0') << hex << gru_in_bias[i] << endl;
	for (int i = 0; i < 32; i++) 
		file  <<  setw(8) << setfill('0') << hex << gru_ir_bias[i] << endl;
	for (int i = 0; i < 32; i++) 
		file  <<  setw(8) << setfill('0') << hex << gru_iz_bias[i] << endl;
	for (int i = 0; i < 32; i++) 
		file  <<  setw(8) << setfill('0') << hex << gru_hn_bias[i] << endl;
	for (int i = 0; i < 32; i++) 
		file  <<  setw(8) << setfill('0') << hex << gru_hr_bias[i] << endl;
	for (int i = 0; i < 32; i++) 
		file  <<  setw(8) << setfill('0') << hex << gru_hz_bias[i] << endl;
	for (int i = 0; i < 13; i++) 
		file  <<  setw(8) << setfill('0') << hex << fc_state_bias[i] << endl;
	for (int i = 0; i < 2; i++) 
		file  <<  setw(8) << setfill('0') << hex << fc_conf_bias[i] << endl;
	for (int i = 0; i < 32; i++) 
		file  <<  setw(8) << setfill('0') << hex << fc_l2h_bias[i] << endl;

	file.close();
}

void CVAE::L2H_FC() {
	for (int i = 0; i < 32; i++) {
		hidden_buffer[0][i] = 0;
		for (int j = 0; j < 4; j++) {
			DT source = z_in[j];
			DT weight = fc_l2h_weights[i * 4 + j];
			DOUBLE_DT partial_sum = (source * weight);
			hidden_buffer[0][i] += partial_sum >> QUAN;
		}
		hidden_buffer[0][i] += fc_l2h_bias[i];
		
		//printf("Hidden[%d]: %e\n", i, hidden_buffer[0][i] / pow(2, QUAN));
	}

	for (int i = 0; i < 13; i++)
		state_buffer[0][i] = s_in[i]; // Copy to initial state

}
void CVAE::STATE_FC() {
	for (int i = 0; i < 13; i++) {
		state_buffer[seq_lens+1][i] = 0;
		for (int j = 0; j < 32; j++) {
			DT source = hidden_buffer[seq_lens + 1][j];
			DT weight = fc_state_weights[i * 32 + j] ;
			
			DOUBLE_DT partial_sum = (source * weight);
			state_buffer[seq_lens + 1][i] += partial_sum >> QUAN;
		}

		state_buffer[seq_lens + 1][i] += fc_state_bias[i];

		//printf("Hidden[%d]: %e\n", i, hidden_buffer[0][i]);
	}
}
void CVAE::CONF_FC() {
	DT sources[38];
	// concate out[32] & goal[6]
	for (int i = 0; i < 32; i++)
		sources[i] = hidden_buffer[seq_lens + 1][i];
	for (int i = 0; i < 6; i++)
		sources[32+i] = s_goal[i];

	for (int i = 0; i < 2; i++) {
		conf_buffer[seq_lens + 1][i] = 0;
		for (int j = 0; j < 38; j++) {
			DT source = sources[j];
			DT weight = fc_conf_weights[i * 38 + j];
			DOUBLE_DT partial_sum = (source * weight);
			conf_buffer[seq_lens + 1][i] += partial_sum >> QUAN;
		}

		conf_buffer[seq_lens + 1][i] += fc_conf_bias[i];

		//printf("CONF[%d]: %08x\n", i, conf_buffer[seq_lens + 1][i]);
	}
}
void CVAE::GRU() {
	DT R[32];
	DT Z[32];
	DT N[32];
	DT X[19];

	// concate X
	for (int i = 0; i < 13; i++)
		X[i] = state_buffer[seq_lens][i];
	for (int i = 0; i < 6; i++)
		X[13 + i] = s_goal[i];

	//for (int i = 0; i < 19; i++)
	//	printf("trg_in[%d]: %e\n", i, X[i]);
	//for (int i = 0; i < 32; i++)
	//	printf("hidden[%d]: %lf\n", i, hidden_buffer[seq_lens][i] / pow(2, QUAN));
	//
	//Rt
	
	
	for (int i = 0; i < 32; i++) {
		DT acc_HR = 0;
		for (int j = 0; j < 32; j++) {
			DT source = hidden_buffer[seq_lens][j];
			DT weight = gru_hr_weights[i * 32 + j] ;
			DOUBLE_DT partial_sum = (source * weight);
			acc_HR += partial_sum >> QUAN;
		}
		acc_HR += gru_hr_bias[i];
		FC_HR_buffer[seq_lens][i] = acc_HR;

		DT acc_IR = 0;
		for (int j = 0; j < 19; j++) {
			DT source = X[j];
			DT weight = gru_ir_weights[i * 19 + j];
			DOUBLE_DT partial_sum = (source * weight);
			acc_IR += partial_sum >> QUAN;
		}
		acc_IR += gru_ir_bias[i];
		FC_IR_buffer[seq_lens][i] = acc_IR;
		//printf("R[%d]: %lf\n", i, R[i] / pow(2, QUAN));
		//double val = (double)R[i] / pow(2, QUAN);
		//val = sigmoid(val);
		//printf("R[%d]: %lf\n", i, val);
		//R[i] = val * pow(2, QUAN);
		R[i] = acc_IR + acc_HR;
	
		R[i] = R[i] >> (QUAN - 16);
		//printf("R_before[%d]: %X\n", i, (int)R[i]);
		R[i] = cordic(R[i], SIGMOID);
		//printf("R_after[%d]: %X\n", i, (int)R[i]);
		R[i] = R[i] << (QUAN - 16);
	}

	// Zt
	for (int i = 0; i < 32; i++) {
		DT acc_HZ = 0;
		for (int j = 0; j < 32; j++) {
			DT source = hidden_buffer[seq_lens][j];
			DT weight = gru_hz_weights[i * 32 + j];
			DOUBLE_DT partial_sum = (source * weight);
			acc_HZ += partial_sum >> QUAN;
		}
		acc_HZ += gru_hz_bias[i];
		FC_HZ_buffer[seq_lens][i] = acc_HZ;
		//cout << "HZ[" << seq_lens << "]" << hex << FC_HZ_buffer[seq_lens][i] << endl;

		DT acc_IZ = 0;
		for (int j = 0; j < 19; j++) {
			DT source = X[j];
			DT weight = gru_iz_weights[i * 19 + j];
			DOUBLE_DT partial_sum = (source * weight);
			acc_IZ += partial_sum >> QUAN;
		}
		acc_IZ += gru_iz_bias[i];

		FC_IZ_buffer[seq_lens][i] = acc_IZ;

		//double val = (double)Z[i] / pow(2, QUAN);
		//val = sigmoid(val);
		//Z[i] = val * pow(2, QUAN);
		Z[i] = acc_IZ + acc_HZ;
		Z[i] = Z[i] >> (QUAN - 16);
		Z[i] = cordic(Z[i], SIGMOID);
		Z[i] = Z[i] << (QUAN - 16);
		//printf("Z[%d]: %lf\n", i, Z[i] / pow(2, QUAN));
	}

	// Nt
	for (int i = 0; i < 32; i++) {
		N[i] = 0;

		DT acc_HN = 0;
		for (int j = 0; j < 32; j++) {
			DT source = hidden_buffer[seq_lens][j];
			DT weight = gru_hn_weights[i * 32 + j];
			DOUBLE_DT partial_sum = (source * weight);
			acc_HN += partial_sum >> QUAN;
		}
		acc_HN += gru_hn_bias[i];
		FC_HN_buffer[seq_lens][i] = acc_HN;

		DOUBLE_DT partial_sum = R[i] * acc_HN;
		N[i] += partial_sum >> QUAN ;

		DT acc_IN = 0;
		for (int j = 0; j < 19; j++) {
			DT source = X[j];
			DT weight = gru_in_weights[i * 19 + j];
			DOUBLE_DT partial_sum = (source * weight);
			acc_IN += partial_sum >> QUAN;
		}
		acc_IN += gru_in_bias[i];
		FC_IN_buffer[seq_lens][i] = acc_IN;

		N[i] += acc_IN;
		N[i] = N[i] >> (QUAN - 16);
		//printf("N_before[%d]: %X\n", i, (int)N[i]);
		N[i] = cordic(N[i], TANH);
		//printf("N_after[%d]: %X\n", i, (int)N[i]);
		N[i] = N[i] << (QUAN - 16);

		//printf("N[%d]: %lf\n", i, N[i]/pow(2, QUAN));
	}

	// Ht
	//printf("[%d]----------------------\n", seq_lens+1);
	for (int i = 0; i < 32; i++) {
		hidden_buffer[seq_lens + 1][i] = 0;

		DT source1 = ((1 << QUAN) - Z[i]);
		DT source2 = N[i];
		
		DOUBLE_DT partial_sum = (source1 * source2);
		
		hidden_buffer[seq_lens + 1][i] += partial_sum >> QUAN;

		source1 = Z[i] ;
		source2 = hidden_buffer[seq_lens][i];
		//printf("T_cross[%d]: %X\n", i, (int)hidden_buffer[seq_lens + 1][i]);
		//printf("Z_cross[%d]: %X\n", i, (int)(source1 * source2));
		partial_sum = (source1 * source2);
		hidden_buffer[seq_lens + 1][i] += partial_sum >> QUAN;
		//printf("Hidden[%d]: %X\n", i, (int)hidden_buffer[seq_lens + 1][i]);


	}

}

void CVAE::compute() {

	L2H_FC();
	while (seq_lens < MAX_LEN - 1) {
		GRU();
		CONF_FC();
		STATE_FC();

		seq_lens++;

		if (conf_buffer[seq_lens][0] < conf_buffer[seq_lens][1])
			break;
	}
}


void CVAE::verify_result(void) {
	printf("--------Result-------\n");
	printf("	Sequens length: %d\n", seq_lens);

	printf("	Conf : %lf %lf\n\n", conf_buffer[seq_lens][0]/pow(2, QUAN), conf_buffer[seq_lens][1] / pow(2, QUAN));
	for (int i = 0; i < 13; i++)
		printf("	State[%d]: %lf\n", i, state_buffer[seq_lens][i] / pow(2, QUAN));

	fstream file;
	double golden_states[13 * MAX_LEN];
	double golden_seq_lens;
	//file.open("data/golden/state_buf.csv", ios::in);
	file.open("data/golden/state_buf_0.csv", ios::in);
	for (int i = 0; i < 13 * MAX_LEN; i++)
		file >> golden_states[i];
	file.close();
	//file.open("data/golden/seq_lens.csv", ios::in);
	file.open("data/golden/seq_lens_0.csv", ios::in);
		file >> golden_seq_lens;
	file.close();

	if ((int)golden_seq_lens != seq_lens)
		printf("[ERROR]: gold: %d , yours: %d\n", (int)golden_seq_lens, seq_lens);

	double total_error = 0;
	double max_error = 0;
	int count = 0;
	int index = 0;
	for (int s = 0; s < seq_lens; s++)
		for (int i = 0; i < 13; i++) {
			double err = abs(golden_states[s * 13 + i] - (state_buffer[s][i]/pow(2, QUAN)));
			index = max_error > err ? index : s*13+i;
			max_error = max(max_error, err);

			//cout << "State[" << s*13+i << "]: " << hex << state_buffer[s][i] << endl;
			total_error += err*err;
			count++;
		}
	printf("RMS         error: %.3lf \n", sqrt(total_error / count));
	printf("Max   [%d]  error: %.3lf \n", index, max_error);
}
