module.exports = {
  css: {
    loaderOptions: {
      sass: {
        sassOptions: {
          silenceDeprecations: ["import", "global-builtin", "color-functions", "if-function", "legacy-js-api"],
        },
      },
    },
  },
  publicPath: "./",
  // added to fix the build of https://github.com/nethesis/ns8-nethvoice-proxy/pull/169
  transpileDependencies: ["axios"],
  configureWebpack: {
    optimization: {
      splitChunks: {
        maxSize: 500000,
      },
    },
  },
  chainWebpack: (config) => {
    config.module
      .rule("images")
      .use("url-loader")
      .loader("url-loader")
      .tap((options) => {
        // Do not base64 encode images URLs. Needed to always generate module logo image
        options.limit = -1;
        return options;
      });
  },
};
