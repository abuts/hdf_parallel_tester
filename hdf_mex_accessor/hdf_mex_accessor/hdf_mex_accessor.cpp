// hdf_mex_accessor.cpp : Defines the exported functions for the DLL application.
//

#include "hdf_mex_accessor.h"

std::unique_ptr<hdf_pix_accessor> pFile_reader;

void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])
{

	const char REVISION[] = "$Revision:: 1524 $ ($Date:: 2017-09-27 15:48:11 +0100 (Wed, 27 Sep 2017) $)";
	if (nrhs == 0 && nlhs == 1) {
		plhs[0] = mxCreateString(REVISION);
		return;
	}

	//* Check and parce input  arguments. */
	input_file new_input_file;
	uint64_t **pBlock_pos(NULL);
	uint64_t **pBlock_sizes(NULL);
	size_t n_blocks,start_pos,pix_buf_size,n_threads;
	int n_bytes(0);

	auto work_type = parse_inputs(nlhs, plhs, nrhs, prhs,
		new_input_file,
		pBlock_pos, pBlock_pos, n_blocks, n_bytes, start_pos,
		pix_buf_size, n_threads);

	if (work_type != close_file && pFile_reader.get() == nullptr) {
		work_type = open_and_read_data;
	}
	plhs[pix_array] = mxCreateNumericMatrix(9, pix_buf_size, mxSINGLE_CLASS, mxREAL);
	plhs[read_block_sizes] = mxDuplicateArray(prhs[block_sizes]);
	plhs[last_read_block_number] = mxCreateDoubleScalar(start_pos);

	float *pixArray = mxGetSingles(plhs[pix_array]);
	switch (work_type)
	{
	case close_file:
		pFile_reader.reset(nullptr);
		break;
	case open_and_read_data:
		pFile_reader.reset(new hdf_pix_accessor());
		pFile_reader->init(new_input_file.filename, new_input_file.groupname);
	case read_initiated_data:
		pFile_reader->read_pixels(pBlock_pos, pBlock_pos, n_blocks,start_pos,
			pixArray, pix_buf_size);
		break;
	default:
		break;
	}
	double *pLastBlock = (double *)mxGetPr(plhs[last_read_block_number]);
	*pLastBlock = double(start_pos);
}

