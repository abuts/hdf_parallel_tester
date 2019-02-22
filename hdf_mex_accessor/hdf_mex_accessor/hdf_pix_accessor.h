#pragma once

#include <string>
#include <sstream>
#include <vector>

#include <hdf5.h>
#include <hdf5_hl.h>
#include <zlib.h>
#include <szlib.h>

#include <mex.h>

class hdf_pix_accessor
{
public:
	void init(const std::string &filename, const std::string &pix_group_name);
	size_t read_pixels(uint64_t **block_pos, 
		uint64_t **block_sizes,size_t n_blocks_in_blocks, size_t &start_pos,
		float *const pix_buffer, size_t n_pixels);
	hdf_pix_accessor();
	~hdf_pix_accessor();
private:
	std::string filename;
	std::string pix_group_name;

	hid_t  file_handle;
	hid_t  file_space_id;
	hid_t  pix_dataset;
	hid_t  pix_data_id;
	hid_t  pix_group_id;
	hid_t  io_mem_space;

	hsize_t max_num_pixels_;
	size_t  io_chunk_size_;

	void close_pix_dataset();
	hsize_t set_block_params(uint64_t &block_pos, uint64_t &block_size,
		size_t pix_buf_size, hsize_t *const block_start,
		hsize_t *const pix_chunk_size,hsize_t &read_pos);
};

