# Books

This is a tiny toolchain for creating a static website with information about
the books I've been reading. Books are saved in a plaintext format (see
[books.txt](./books.txt)) and converted into an html file.

The final output is hosted at [clarity.flowers/books](https://clarity.flowers/books).

This repo uses submodules for libraries, so you'll want to do `git submodules init`.

The generator is built with [Zig](https://ziglang.org/). I try to stay up to
date with the latest dev version, so it usually should work with that.

The command uses `stdin` and `stdout` for generation. The way I use it right now
is like this:

```bash
cat books.txt | zig build run > public/index.html
```

But you could also add `<project-folder>/zig-cache/bin` to your path and then
run the `books` command however you like!

All books that have been started or finished expect to have an associated `.png` image
file with the same name as the book, except with spaces replaced with underscores.
