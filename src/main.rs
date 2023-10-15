use std::{mem::MaybeUninit, thread, f64::consts::E};

use image;
use num_complex;

#[inline]
unsafe fn write_color(p: *mut u8, imgx: usize, x: usize, y: usize, r: u8, g: u8, b: u8) {
    *p.offset((3 * (x + imgx * y) + 0) as isize) = r;
    *p.offset((3 * (x + imgx * y) + 1) as isize) = g;
    *p.offset((3 * (x + imgx * y) + 2) as isize) = b;
}

fn main() {
    let cpus = 4;
    let imgx = 2000;
    let imgy = 2000;

    let mut v: Vec<u8> = Vec::with_capacity(imgx * imgy * 3);
    let p = v.spare_capacity_mut() as *mut [MaybeUninit<u8>] as *mut MaybeUninit<u8> as usize;

    thread::scope(|s| {
        for i in 0..cpus {
            s.spawn(move || {
                println!("cpu{}", i);
                let p = p as *mut u8;
                for xy in (i..imgx*imgy).step_by(cpus) {
                    let x = xy % imgx;
                    let y = xy / imgx;

                    let cx = x as f64 / imgx as f64 * 4.0 - 2.0;
                    let cy = y as f64 / imgy as f64 * 4.0 - 2.0;

                    let mut zx = 0.0;
                    let mut zy = 0.0;

                    let mut d = 1e6;

                    for _ in 0..10000 {
                        let tx = zx;
                        zx = zx * zx - zy * zy + cx;
                        zy = 2.0 * tx * zy + cy;

                        if d > zx * zx + zy * zy {
                            d = zx * zx + zy * zy;
                        }
                    }

                    unsafe {
                        // if zx * zx + zy * zy < 4.0 {
                        //     write_color(p, imgx, x, y, 0, 0, 0);
                        // } else {
                        //     write_color(p, imgx, x, y, 255, 255, 255);
                        // }
                        let c = (255.0 / E.powf(d*10.0)) as u8;
                        write_color(p, imgx, x, y, c, c, c);
                    }
                }
                println!("cpu{i} end");
            });
        }
        println!("spawn end");
    });

    unsafe {
        v.set_len(imgx * imgy * 3);
    }

    image::save_buffer("img.png", &v, imgx as u32, imgy as u32, image::ColorType::Rgb8).unwrap();
}
