#include "input_parser.h"
#include <vector>
#include <hdf5.h>


int get_byte_length(const char*error_id, const mxArray *param) {

	mxClassID category = mxGetClassID(param);

	switch (category) {
	case mxINT64_CLASS:    return 8;
	case mxUINT64_CLASS:   return 8;
	case mxDOUBLE_CLASS:   return 8;
	default: {
		std::stringstream buf;
		buf << " The input data for " << error_id << "should be of 8 bytes length digital type";
		mexErrMsgIdAndTxt("HDF_MEX_ACCESS:invalid_argument", buf.str().c_str());
		return -1;
	}
	}
}

template<typename T>
T retrieve_value(const char*err_id, const mxArray *prhs) {



	size_t m_size = mxGetM(prhs);
	size_t n_size = mxGetN(prhs);
	if (m_size != 1 || n_size != 1) {


		std::stringstream buf;
		buf << " The input for " << err_id << "should be a single value while its size is ["
			<< m_size << "x" << n_size << "] Matrix\n";
		mexErrMsgIdAndTxt("HDF_MEX_ACCESS:invalid_argument", buf.str().c_str());
	}

	auto *pVector = mxGetPr(prhs);

	return static_cast<T>(pVector[0]);
}

void retrieve_vector(const char*err_id, const mxArray *prhs, uint64_t **pVector, size_t &vec_size, int &vec_bytes) {

	*pVector = reinterpret_cast<uint64_t *>(mxGetPr(prhs));

	size_t m_size_a = mxGetM(prhs);
	size_t n_size_a = mxGetN(prhs);
	size_t m_size, n_size;
	if (n_size_a > m_size_a) {
		m_size = n_size_a;
		n_size = m_size_a;
	}
	else {
		m_size = m_size_a;
		n_size = n_size_a;
	}
	if (n_size == 1)
		vec_size = m_size;
	else {
		std::stringstream buf;
		buf << " The input for " << err_id << "should be a 1D vector while its size is ["
			<< m_size_a << "x" << n_size_a << "] Matrix\n";
		mexErrMsgIdAndTxt("HDF_MEX_ACCESS:invalid_argument", buf.str().c_str());
	}

	vec_bytes = get_byte_length(err_id, prhs);
}

void retrieve_string(const mxArray *param, std::string &result, const char *ErrorPrefix) {

	mxClassID  category = mxGetClassID(param);
	if (category != mxCHAR_CLASS) {
		std::stringstream err;
		err << "first argument should be hdf " << ErrorPrefix << "word \'close\' when in fact its not a string\n ";
		mexErrMsgIdAndTxt("HDF_MEX_ACCESS:invalid_argument",
			err.str().c_str());
	}
	auto buflen = mxGetNumberOfElements(param) + 1;
	result.resize(buflen);
	auto pBuf = &(result[0]);

	/* Copy the string data from string_array_ptr and place it into buf. */
	if (mxGetString(param, pBuf, buflen) != 0) {
		std::stringstream err;
		err << " Can not convert string data while processing" << ErrorPrefix << "\n";
		mexErrMsgIdAndTxt("HDF_MEX_ACCESS:invalid_argument",
			err.str().c_str());
	}

}

/** The variable keeping information about the recent input file to identify status of subsequent access requests to this file*/
input_file current_input_file;

/** process input values and extract parameters, necessary for the reader to work in the form the program requests
*Inputs:
*
*Ouptuts:
new_file          -- the structure, containing filename and datafolder to process.
block_positions   -- pointer to the array of the posisions of the blocks to read
block_sizes       -- pointer to the array of the posisions of the blocks to read
n_blocks_to_read  -- the size of the block positions and block sizes array
n_bytes           -- the size of the pointer of block_positions and block_size array
start_pos         -- the initial position in the block_positions/block_size arrays to
					 read data from.
buf_size          -- the maximal number of pixels to read in one operation
num_threads       -- number of OMP threads to use in i/o operation
*/
input_types parse_inputs(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[],
	input_file &new_file,
	uint64_t *block_pos[], uint64_t *block_size[], size_t &n_blocks_to_read, int &n_bytes, size_t &start_pos,
	size_t &buf_size, size_t &n_threads) {

	input_types input_kind;

	//* Check for proper number of arguments. */
	{
		if (nrhs != N_INPUT_Arguments && nrhs != 2) {
			std::stringstream buf;
			buf << " mex needs 2 or " << (short)N_INPUT_Arguments << " inputs but got " << (short)nrhs
				<< " input(s) and " << (short)nlhs << " output(s)\n";
			mexErrMsgIdAndTxt("HDF_MEX_ACCESS:invalid_argument",
				buf.str().c_str());
		}
		if (nlhs != N_OUTPUT_Arguments && nrhs > 2) {
			std::stringstream buf;
			buf << " mex needs " << (short)N_OUTPUT_Arguments << " outputs but requested to return" << (short)nlhs << " arguments\n";
			mexErrMsgIdAndTxt("HDF_MEX_ACCESS:invalid_argument",
				buf.str().c_str());
		}

		for (int i = 0; i < nrhs - 1; i++) {
			if (prhs[i] == NULL) {
				std::stringstream buf;
				buf << "argument N" << i << " is not defined\n";
				mexErrMsgIdAndTxt("HDF_MEX_ACCESS:invalid_argument",
					buf.str().c_str());
			}
		}
	}
	// get correct file name and the group name
	retrieve_string(prhs[filename], new_file.filename, "filename");
	retrieve_string(prhs[pixel_group_name], new_file.groupname, "pixel_group_name");

	if (new_file.do_destructor()) {
		block_pos = NULL;
		block_pos = NULL;
		n_blocks_to_read = 0;
		n_bytes = 0;
		start_pos = 0;
		buf_size = 0;
		n_threads = 0;
		return close_file;
	}


	if (new_file.equal(current_input_file))
		input_kind = read_initiated_data;
	else {
		input_kind = open_and_read_data;
		current_input_file = new_file;
	}

	if (nrhs != N_INPUT_Arguments) {
		std::stringstream err;
		err << " if mex used to access the data it needs " << (short)N_INPUT_Arguments << "input arguments but got " << (short)nrhs
			<< " input arguments\n";
		mexErrMsgIdAndTxt("HDF_MEX_ACCESS:invalid_argument",
			err.str().c_str());
	}
	size_t n_blocks;
	retrieve_vector("block_positions", prhs[block_positions], block_pos, n_blocks, n_bytes);
	retrieve_vector("block_sizes", prhs[block_sizes], block_size, n_blocks, n_bytes);

	start_pos = retrieve_value<size_t>("start_position", prhs[start_position]);
	buf_size = retrieve_value<size_t>("pixel_buffer_size", prhs[pix_buf_size]);
	n_threads = retrieve_value<size_t>("number_of_threads", prhs[num_threads]);

	if (start_pos > n_blocks) {
		input_kind = close_file;
		return input_kind;
	}

	uint64_t n_pix_to_read(0), n_pix_to_read_next(0);
	n_blocks_to_read = 0;
	for (size_t i = start_pos; i < n_blocks; ++i) {

		if (n_bytes == 8)
			n_pix_to_read_next += *reinterpret_cast<uint64_t *>(block_size + n_bytes * i);
		else
			n_pix_to_read_next += *reinterpret_cast<uint32_t *>(block_size + n_bytes * i);

		if (n_pix_to_read_next > buf_size) {
			//The case when single block is bigger than the pixels buffer so part of the block needs to be read should be considered separately
			break;
		}
		n_pix_to_read = n_pix_to_read_next;
		n_blocks_to_read++;
	}

	return input_kind;
}