module ApplicationHelper
    def default_meta_tags
    {
      site: 'すいみんにっし',
      title: '睡眠日誌を印刷できる記録サービス',
      reverse: true,
      charset: 'utf-8',
      description: '元睡眠病患者が作った、印刷機能付きの睡眠日誌作成ツールです。',
      keywords: '睡眠,睡眠病,睡眠クリニック,睡眠日誌,睡眠記録,突発性過眠症',
      canonical: 'https://sleeplogger.onrender.com/',
      separator: '|',
      og:{
        site_name: :site,
        title: :title,
        description: :description,
        type: 'website',
        url: 'https://sleeplogger.onrender.com/',
        image: image_url('ogp.png'),
        local: 'ja-JP'
      },
      twitter: {
        card: 'summary_large_image',
        site: '@miyamagear',
        image: image_url('ogp.png')
      }
    }
  end
end
