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
	double *pBlock_pos(nullptr);
	double *pBlock_sizes(nullptr);
	size_t n_blocks, pix_buf_size, n_threads;
	hsize_t first_block_non_read(1);
	size_t npix_to_read;
	int n_bytes(0);

	auto work_type = parse_inputs(nlhs, plhs, nrhs, prhs,
		new_input_file,
		pBlock_pos, pBlock_sizes, n_blocks, n_bytes,
		pix_buf_size, n_threads,npix_to_read);

	if (work_type != close_file && pFile_reader.get() == nullptr) {
		work_type = open_and_read_data;
	}
	if (nlhs > 0) {
		plhs[pix_array] = mxCreateNumericMatrix(9, npix_to_read, mxSINGLE_CLASS, mxREAL);
	}

	float *pixArray = (float*)mxGetPr(plhs[pix_array]);
	switch (work_type)
	{
	case close_file:
		pFile_reader.reset(nullptr);
		break;
	case open_and_read_data:
		pFile_reader.reset(new hdf_pix_accessor());
		pFile_reader->init(new_input_file.filename, new_input_file.groupname);
	case read_initiated_data:
		pFile_reader->read_pixels(pBlock_pos, pBlock_sizes, n_blocks, first_block_non_read,
			pixArray, pix_buf_size);
		break;
	default:
		break;
	}

	if (nlhs > 1) {
		if (first_block_non_read >= n_blocks) {
			plhs[block_positions_left] = mxCreateNumericMatrix(0, 0, mxDOUBLE_CLASS, mxREAL);
			plhs[block_sizes_left] = mxCreateNumericMatrix(0, 0, mxDOUBLE_CLASS, mxREAL);
		}
		else {
			size_t n_blocks_left = n_blocks - first_block_non_read;
			plhs[block_positions_left] = mxCreateNumericMatrix(n_blocks_left, 1, mxDOUBLE_CLASS, mxREAL);
			plhs[block_sizes_left] = mxCreateNumericMatrix(n_blocks_left, 1, mxDOUBLE_CLASS, mxREAL);

			auto pTargPos = mxGetPr(plhs[block_positions_left]);
			auto pTargSizes = mxGetPr(plhs[block_sizes_left]);
			for (size_t i = first_block_non_read; i < n_blocks; i++) {
				pTargPos[i - first_block_non_read] = pBlock_pos[i];
				pTargSizes[i - first_block_non_read] = pBlock_sizes[i];
			}

		}

	}

}

