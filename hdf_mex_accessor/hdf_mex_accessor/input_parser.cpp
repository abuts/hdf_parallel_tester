#include "input_parser.h"
#include <vector>
#include <hdf5.h>


enum InputArguments {
	filename,
	pixel_group_name,

	block_positions,
	block_sizes,
	start_position,

	pix_buf_size,
	num_threads,
	N_INPUT_Arguments
};
enum OutputArguments { // unique output arguments,
	pix_array,
	last_read_block_number,
	N_OUTPUT_Arguments
};

void retrieve_string(const mxArray *param, std::string &result, const char *ErrorPrefix) {

	mxClassID  category = mxGetClassID(param);
	if (category != mxCHAR_CLASS) {
		std::stringstream err;
		err << "first argument should be hdf " << ErrorPrefix << "word \'close\' when in fact its not a string\n ";
		mexErrMsgIdAndTxt("HDF_MEX_ACCESS::invalid_argument",
			err.str().c_str());
	}
	auto buflen = mxGetNumberOfElements(param) + 1;
	result.resize(buflen);
	auto pBuf = &(result[0]);

	/* Copy the string data from string_array_ptr and place it into buf. */
	if (mxGetString(param, pBuf, buflen) != 0) {
		std::stringstream err;
		err << " Can not convert string data while processing" << ErrorPrefix << "\n";
		mexErrMsgIdAndTxt("HDF_MEX_ACCESS::invalid_argument",
			err.str().c_str());
	}

}

input_file current_input_file;

/**/
input_types parse_inputs(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[],
	input_file &new_file,std::vector<hsize_t> &block_positions, std::vector<hsize_t> &block_sizes,size_t &start_pos,
	size_t &pix_buf_size,size_t &num_threads) {

	input_types input_kind;

	//* Check for proper number of arguments. */
	{
		if (nrhs != N_INPUT_Arguments && nrhs != 2) {
			std::stringstream buf;
			buf << " mex needs 2 or " << (short)N_INPUT_Arguments << " inputs but got " << (short)nrhs
				<< " input(s) and " << (short)nlhs << " output(s)\n";
			mexErrMsgIdAndTxt("HDF_MEX_ACCESS::invalid_argument",
				buf.str().c_str());
		}
		if (nlhs != N_OUTPUT_Arguments) {
			std::stringstream buf;
			buf << " mex needs " << (short)N_OUTPUT_Arguments << " outputs but requested to return" << (short)nlhs << " arguments\n";
			mexErrMsgIdAndTxt("HDF_MEX_ACCESS::invalid_argument",
				buf.str().c_str());
		}

		for (int i = 0; i < nrhs - 1; i++) {
			if (prhs[i] == NULL) {
				std::stringstream buf;
				buf << "argument N" << i << " is not defined\n";
				mexErrMsgIdAndTxt("HDF_MEX_ACCESS::invalid_argument",
					buf.str().c_str());
			}
		}
	}
	// get correct file name and the group name
	retrieve_string(prhs[filename], new_file.filename, "filename");
	retrieve_string(prhs[pixel_group_name], new_file.groupname, "pixel_group_name");

	if (new_file.is_destructor()) return close_file;


	if (new_file.equal(current_input_file))
		input_kind = read_data_ready;
	else input_kind = open_and_read_data;

	if (nrhs != N_INPUT_Arguments) {
		std::stringstream err;
		err << " if mex used to access the data it needs " << (short)N_INPUT_Arguments << "input arguments but got " << (short)nrhs
			<< " input arguments\n";
		mexErrMsgIdAndTxt("HDF_MEX_ACCESS::invalid_argument",
			err.str().c_str());
	}


	return input_kind;
}