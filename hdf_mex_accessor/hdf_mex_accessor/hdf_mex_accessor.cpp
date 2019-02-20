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

	parse_inputs(nlhs,plhs,nrhs, prhs, new_input_file, );
}

