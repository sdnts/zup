const zig = Bun.serve({
  port: 8000,
  async fetch(request) {
    const url = new URL(request.url);
    console.log("(zig) Incoming request", url.pathname);

    if (url.pathname === "/download/index.json") {
      return new Response(await Bun.file("src/zig.json").text(), {
        headers: { "Content-Type": "application/json" },
      });
    }

    if (url.pathname.startsWith("/builds/")) {
      return new Response(Bun.file("src/zig.tar.xz"));
    }

    return new Response("Bad Request", { status: 400 });
  },
});
console.log(`(zig) Serving on ${zig.port}`);

const zls = Bun.serve({
  port: 9000,
  async fetch(request) {
    const url = new URL(request.url);
    console.log("(zls) Incoming request", url.pathname);

    if (url.pathname === "/zls/index.json") {
      return new Response(await Bun.file("src/zls.json").text(), {
        headers: { "Content-Type": "application/json" },
      });
    }

    if (url.pathname.startsWith("/zls/")) {
      return new Response(Bun.file("src/zls"));
    }

    return new Response("Bad Request", { status: 400 });
  },
});
console.log(`(zls) Serving on ${zls.port}`);
