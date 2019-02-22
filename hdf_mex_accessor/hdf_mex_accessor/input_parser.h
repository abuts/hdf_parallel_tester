#pragma once

#include <mex.h>
#include <string>
#include <sstream>


enum input_types {
	close_file,
	open_and_read_data,
	read_initiated_data
};
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
	read_block_sizes,
	last_read_block_number,
	N_OUTPUT_Arguments
};


/* The structure defines the position of the pixel dataset in an nxsqw hdf file and consist of
   the name of the file and the full name of the group, containing pixels dataset*/
struct input_file {
	/* the name of hdf file to access pixels */
	std::string filename;
	/*the name of the group, containing pixels information */
	std::string groupname;

	/* check if the name and group name of other input file are equal to the current file*/
	bool equal(input_file &other_file) {
		if (other_file.filename == this->filename && other_file.groupname == this->groupname)
			return true;
		else return false;
	}
	bool do_destructor() {
		if (this->filename.compare("close") || this->groupname.compare("close"))return true;
		else return false;
	}
	input_file& operator=(const input_file& other) {
		if (this != &other) {
			this->filename = other.filename;
			this->groupname = other.groupname;
		}
		return *this;
	}

};

input_types parse_inputs(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[],
	input_file &new_file,
	uint64_t *block_pos[], uint64_t *block_size[], size_t &n_blocks, int &n_bytes, size_t &start_pos,
	size_t &buf_size, size_t &n_threads);
