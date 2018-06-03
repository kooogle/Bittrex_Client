class User < ActiveRecord::Base
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable

  def admin?
    return true if self.role == 0
    return false
  end

  def roles
    {0=>'管理员',2=>'普通用户'}[self.role]
  end

  def self.sms_yunpian(mobile,content)
    yunpian = 'https://sms.yunpian.com/v2/sms/tpl_single_send.json'
    params = {}
    params[:apikey] = Settings.yunpian_key
    params[:tpl_id] = '1950240'
    params[:mobile] = mobile
    params[:tpl_value] = URI::escape('#report#') + '='+ URI::escape(content)
    Faraday.send(:post,yunpian, params)
  end

  def self.sms_batch(content)
    mobiles = ['18211109527','13426000026']
    mobiles.map {|mobile| User.sms_yunpian(mobile,content) }
  end

  def self.sms_notice(content)
    mobile = '18211109527'
    User.sms_yunpian(mobile,content)
  end

  def self.sms_bao(content)
    string = "【Block】代币价格通知：#{content}"
    sms_url = 'http://api.smsbao.com/sms'
    res = Faraday.get do |req|
      req.url sms_url
      req.params['u'] = Settings.sms_username
      req.params['p'] = Digest::MD5.hexdigest(Settings.sms_password)
      req.params['m'] = '18211109527'
      req.params['c'] = string
    end
  end

  def self.wechat_group_notice(title,content)
    push_url = 'https://pushbear.ftqq.com/sub'
    res = Faraday.get do |req|
      req.url push_url
      req.params['sendkey'] = '3969-7430d6c874dc6c071f4a20d1d92b4935'
      req.params['text'] = title
      req.params['desp'] = content
    end
  end

  def self.wechat_notice(title,content)
    push_url = 'https://sc.ftqq.com/SCU16737Tfd4e2c97f2d967e26cd629f1f87ca4345a1bc153e6755.send'
    res = Faraday.get do |req|
      req.url push_url
      req.params['text'] = title
      req.params['desp'] = content
    end
  end

end
