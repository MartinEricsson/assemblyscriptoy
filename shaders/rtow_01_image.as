// ============================================================
//  Ray Tracing in One Weekend — Output an Image
// ============================================================
//  The book's first program writes a 256x256 PPM. Here the same
//  image is stored in the playground's pixel buffer: red grows
//  left to right, green grows top to bottom, and the lower-right
//  corner is yellow.
//
//  main() runs once per frame and must write all 65,536 pixels.
//  Pixel i lives at byte 16 + i * 12 as three i32 channels.
//
//  Color math stays in f32 and scales with 255.0. Unsuffixed
//  literals such as 255.999 are f64; Gasm's loop parallelizer
//  can drop those conversions and leave a black frame.
// ============================================================

const WIDTH: i32 = 256;
const HEIGHT: i32 = 256;

export function main(): void {
  const totalPixels: i32 = WIDTH * HEIGHT;

  for (let i: i32 = 0; i < totalPixels; i++) {
    const x: i32 = i % WIDTH;
    const y: i32 = i / WIDTH;

    const rf: f32 = <f32>x / 255.0;
    const gf: f32 = <f32>y / 255.0;

    const pixelOffset: i32 = 16 + i * 12;
    store<i32>(pixelOffset, <i32>(rf * 255.0));
    store<i32>(pixelOffset + 4, <i32>(gf * 255.0));
    store<i32>(pixelOffset + 8, 0);
  }
}
