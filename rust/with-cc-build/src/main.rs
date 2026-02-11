use std::fs::File;
use std::io::BufReader;
use std::path::PathBuf;
use tar::Archive;

fn main() {
    let source_filepath = PathBuf::from("hello.tar.zst");
    let source_file = File::open(&source_filepath).unwrap();
    let reader = BufReader::new(source_file);
    let archive_reader = zstd::stream::Decoder::new(reader).unwrap();
    let extraction_directory = PathBuf::from("hello");
    Archive::new(archive_reader).unpack(extraction_directory).unwrap();
}
