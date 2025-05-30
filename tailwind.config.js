module.exports = {
  content: [
    './app/views/**/*.html.erb',
    './app/helpers/**/*.rb',
    './app/assets/stylesheets/**/*.css',
    './app/javascript/**/*.js'
  ],
  theme: {
    extend: {
      keyframes: {
        flashMessageIn: { // スライドイン・フェードイン
          '0%': { opacity: 0, transform: 'translateY(0)'},
          '20%': { opacity: 1, transform: 'translateY(100%)' },
          },
          flashMessageOut: { // スライドアウト・フェードアウト
            '80%': { opacity: 1, transform: 'translateY(100%)' },
            '100%': { opacity: 0, transform: 'translateY(0)' },
          },
        },
        animation: {
          'flash-message-in': 'flashMessageIn 0.5s ease-out forwards', // 最初早く後遅く、0.5秒後に発動
          'flash-message-out': 'flashMessageOut 0.5s ease-in forwards', // 最初遅く後早く
        },
      },
    },
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
          "warning": "#E1335E", // 濃いピンク
          "error": "#8d7683", /// 赤
          },
        },
      ],
      darkTheme: false, // ダークテーマを採用しない
    },
};