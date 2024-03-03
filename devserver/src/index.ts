const server = Bun.serve({
  port: 3000,
  async fetch(request) {
    const url = new URL(request.url);
    console.log("Incoming request", url.pathname);

    if (url.pathname === "/zig/index.json") {
      return new Response(await Bun.file("src/zig.json").text(), {
        headers: { "Content-Type": "application/json" },
      });
    }
    if (url.pathname === "/zig") {
      return new Response(Bun.file("src/zig.tar.xz"));
    }

    if (url.pathname === "/zls/index.json") {
      return new Response(await Bun.file("src/zls.json").text(), {
        headers: { "Content-Type": "application/json" },
      });
    }
    if (url.pathname === "/zls") {
      return new Response(Bun.file("src/zls"));
    }

    return new Response("ok");
  },
});
console.log(`Running on ${server.port}`);
