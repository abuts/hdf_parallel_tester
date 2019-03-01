#pragma once

#include <string>
#include <sstream>
#include <vector>

#include <hdf5.h>
#include <hdf5_hl.h>
#include <zlib.h>
#include <szlib.h>

#include <mex.h>
#include "input_parser.h"

class hdf_pix_accessor
{
public:
    void init(const std::string &filename, const std::string &pix_group_name);
    size_t read_pixels(double *const block_pos, 
        double *const block_sizes,size_t n_blocks_in_blocks, size_t &start_pos,
        float *const pix_buffer, size_t n_pixels);
    size_t read_pixels(const pix_processing_block&pix_split_info, float *const pix_buffer);

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
    bool set_block_params(double &block_pos, double &block_size,
        size_t &n_pix_selected, size_t &pix_buf_size,
        hsize_t *const block_start,
        hsize_t *const pix_chunk_size,
        hsize_t &first_block_non_read);
};

