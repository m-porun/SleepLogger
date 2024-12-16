module.exports = {
  content: [
    './app/views/**/*.html.erb',
    './app/helpers/**/*.rb',
    './app/assets/stylesheets/**/*.css',
    './app/javascript/**/*.js'
  ],
  plugins: [require("daisyui")],
  daisyui: {
    themes: [
      {
        mytheme: {
          "primary": "#f5f5f5", // 白色
          "secondary": "#c3c3c3", // グレー
          "accent": "#5862ab", // 青
          "neutral": "#3d3a39", // 黒
          "base-100": "#e3e0dc", // 薄グレー
          "info": "#5862ab", // 青
          "success": "#5862ab", // 青
          "warning": "#8d7683", // 赤
          "error": "#8d7683", /// 赤
          },
        },
      ],
      darkTheme: false, // ダークテーマを採用しない
    },
}