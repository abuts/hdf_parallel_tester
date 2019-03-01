#pragma once

#include <mex.h>
#include <string>
#include <sstream>


enum input_types {
    close_file,
    open_and_read_data,
    read_initiated_data
};
enum InputArguments { // all input arguments
    filename,
    pixel_group_name,

    block_positions,
    block_sizes,

    pix_buf_size,
    num_threads,
    N_INPUT_Arguments
};

enum OutputArguments { // unique output arguments,
    pix_array,
    block_positions_left,
    block_sizes_left,
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
        if ((this->filename.compare("close") == 0) || (this->groupname.compare("close") == 0))return true;
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
/* The class which describes a block of information necessary to process block of pixels */
class pix_processing_block {
public:
    // number of the first block within the block array
    size_t n_start_block;
    // number of blocks to process
    size_t n_blocks;
    // how many pixels to skip while processing the first block
    size_t pos_in_first_block;
    // how many pixels to take from the last block
    size_t pos_in_last_block;


    // pointer to the array of block positions
    double const *pBlockPos;
    // pointer to the array of block sizes
    double const *pBlockSizes;
    // the initial position of the pixels, described by this block in the pixels buffer;
    size_t  pix_buf_pos;
    pix_processing_block() :
        n_start_block(0), n_blocks(0), pos_in_first_block(0), 
        pBlockPos(nullptr), pBlockSizes(nullptr), pix_buf_pos(0){}
    size_t npix_in_first_block() {
        size_t n_pix_in_block = static_cast<size_t>(this->pBlockSizes[n_start_block]);
        return (n_pix_in_block - this->pos_in_first_block+1);
    };
    size_t npix_in_last_block() {
        return (this->pos_in_last_block+1);
    };
    void init(double const*const block_pos, double const*const block_sizes, size_t last_split_block_num, size_t last_split_block_pos,
        size_t cur_split_block_num, size_t cur_split_block_pos,size_t n_pix_processed_before) {
        this->pBlockPos = block_pos;
        this->pBlockSizes = block_sizes;
        this->n_start_block = last_split_block_num;
        this->pos_in_first_block = last_split_block_pos;
        this->n_blocks = cur_split_block_num - last_split_block_num+1;
        this->pos_in_last_block = cur_split_block_pos;
        this->pix_buf_pos = n_pix_processed_before;
    }

};

input_types parse_inputs(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[],
    input_file &new_file,
    double *&block_pos, double *&block_size, size_t &n_blocks, int &n_bytes,
    size_t &buf_size, std::vector<pix_processing_block> &block_split_info, size_t &npix_to_read);
