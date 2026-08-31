#!/usr/bin/env python3
"""向本地开发后端（内存存储）注入演示数据。

利用后端预置的 3 个种子账号（13800000000/1/2，密码 Demo12345），
再注册 3 个新账号并完成学生认证，然后制造互动：

- 王小雨（13800000001，演示主账号）：收到 9 次点赞、6 条评论、1 条回复、
  3 个私信会话（各 1 条未读招呼）→ 底栏角标约 19；
- 真实测试账号（脚本运行时通过管理员接口发现的非演示账号）：
  收到 2 个私信会话（各 1 条未读招呼）→ 自己的账号也能看到角标。

幂等：若检测到王小雨已有脚本标志帖子，则跳过内容创建，只报告未读数。

用法：python3 scripts/seed_demo_data.py [base_url]
"""
import io
import json
import sys
import urllib.error
import urllib.request
from http.cookiejar import CookieJar

BASE = sys.argv[1] if len(sys.argv) > 1 else 'http://127.0.0.1:8080'
API = BASE + '/api/v1'
INVITE = 'xsnbb-test'
DEMO_PASSWORD = 'Demo12345'   # 种子账号密码
NEW_PASSWORD = 'Test12345'    # 新注册账号密码
ADMIN_USER = 'admin'
ADMIN_PASS = 'Admin12345'
CSRF_HEADER = 'X-CSRF-Token'
MARKER = '图书馆三楼的插座座位'  # 幂等标志：王小雨的脚本帖子正文


def make_avatar(color: str) -> bytes:
    from PIL import Image
    img = Image.new('RGB', (200, 200), color)
    buf = io.BytesIO()
    img.save(buf, format='PNG')
    return buf.getvalue()


class Client:
    def __init__(self, csrf_name: str):
        self.jar = CookieJar()
        self.opener = urllib.request.build_opener(
            urllib.request.HTTPCookieProcessor(self.jar))
        self.csrf_name = csrf_name

    def csrf(self) -> str:
        for c in self.jar:
            if c.name == self.csrf_name:
                return c.value
        return ''

    def call(self, method: str, path: str, body=None):
        data = json.dumps(body).encode() if body is not None else None
        req = urllib.request.Request(API + path, data=data, method=method)
        req.add_header('Content-Type', 'application/json')
        if method in ('POST', 'PUT', 'PATCH', 'DELETE') and self.csrf():
            req.add_header(CSRF_HEADER, self.csrf())
        try:
            with self.opener.open(req, timeout=10) as resp:
                return resp.status, json.loads(resp.read() or b'{}')
        except urllib.error.HTTPError as e:
            return e.code, json.loads(e.read() or b'{}')

    def upload(self, png: bytes, filename: str) -> str:
        boundary = '----seedboundary'
        body = b'\r\n'.join([
            f'--{boundary}'.encode(),
            f'Content-Disposition: form-data; name="file"; filename="{filename}"'.encode(),
            b'Content-Type: image/png',
            b'',
            png,
            f'--{boundary}--'.encode(),
            b'',
        ])
        req = urllib.request.Request(API + '/uploads', data=body, method='POST')
        req.add_header('Content-Type', f'multipart/form-data; boundary={boundary}')
        req.add_header(CSRF_HEADER, self.csrf())
        with self.opener.open(req, timeout=10) as resp:
            return json.loads(resp.read())['url']


def fail(msg: str):
    print(f'[seed] 失败: {msg}')
    sys.exit(1)


def expect(status: int, body, want: int, what: str):
    if status != want:
        fail(f'{what}: HTTP {status} {json.dumps(body, ensure_ascii=False)}')


def login(phone: str, password: str, what: str) -> Client:
    c = Client('xsnbb_csrf')
    s, b = c.call('POST', '/auth/login', {'phone': phone, 'password': password})
    expect(s, b, 200, f'{what} 登录')
    return c


# 种子账号：phone, nickname
SEEDED = [
    ('13800000000', '李大壮'),   # id 1
    ('13800000001', '王小雨'),   # id 2，演示主账号
    ('13800000002', '张同学'),   # id 3
]

# 新注册账号：phone, nickname, gender, real_name, student_no, class_name, color
NEW_USERS = [
    ('13900000001', '自习室常客', '女', '苏静好', '20230222', '外语2303', '#8E5CE6'),
    ('13900000002', '食堂测评员', '男', '范统', '20220630', '机械2205', '#FF6B00'),
    ('13900000003', '羽毛球搭子', '女', '高飞扬', '20230407', '体育2302', '#0EA5B7'),
]

MAIN_NEW_POSTS = [
    ('图书馆三楼的插座座位是真的难抢，今天六点半起床终于占到一回。大家一般几点到？',
     ['图书馆', '自习']),
    ('有没有人想组一个周末羽毛球局？目前三缺一，场地我来订。',
     ['羽毛球', '找搭子']),
]

NEW_USER_POSTS = [
    ('整理了一份期末高频考点笔记，需要的同学评论区扣 1。', ['期末复习', '笔记']),
    ('二食堂新出的糖醋排骨窗口，排队 20 分钟，打分 8.5/10。', ['食堂新品', '测评']),
    ('校羽毛球赛下月开打，双打还缺搭档的私我。', ['羽毛球', '比赛']),
]


def main():
    try:
        with urllib.request.urlopen(BASE + '/healthz', timeout=5) as r:
            json.loads(r.read())
    except Exception as e:
        fail(f'后端不可达 {BASE}: {e}')

    # 1. 种子账号登录：actors 顺序 = 李大壮, 王小雨(主), 张同学
    actors = [login(p, DEMO_PASSWORD, n) for p, n in SEEDED]
    li, yu, zhang = actors
    print('[seed] 3 个种子账号登录成功')

    # 2. 新用户注册（已存在则直接登录）+ 资料 + 认证
    admin = Client('xsnbb_admin_csrf')
    s, b = admin.call('POST', '/admin/auth/login',
                      {'username': ADMIN_USER, 'password': ADMIN_PASS})
    expect(s, b, 200, '管理员登录')

    new_clients = []
    for phone, nick, gender, real, sno, cls, color in NEW_USERS:
        c = Client('xsnbb_csrf')
        s, b = c.call('POST', '/auth/login', {'phone': phone, 'password': NEW_PASSWORD})
        if s != 200:
            s, b = c.call('POST', '/auth/sms-code', {'phone': phone, 'purpose': 'register'})
            expect(s, b, 200, f'{nick} 获取验证码')
            s, b = c.call('POST', '/auth/register', {
                'phone': phone, 'code': b['dev_code'], 'password': NEW_PASSWORD,
                'nickname': nick, 'invite_code': INVITE,
            })
            expect(s, b, 201, f'{nick} 注册')
        s, me = c.call('GET', '/me')
        expect(s, me, 200, f'{nick} 查询资料')
        account = me['account']
        if not account.get('profile_done'):
            avatar = c.upload(make_avatar(color), f'avatar-{phone}.png')
            s, b = c.call('PUT', '/me/profile', {
                'nickname': nick, 'avatar': avatar, 'gender': gender,
                'real_name': real, 'student_no': sno, 'class_name': cls,
            })
            expect(s, b, 200, f'{nick} 完善资料')
        if not account.get('verified'):
            material = c.upload(make_avatar('#999999'), f'material-{phone}.png')
            s, b = c.call('POST', '/me/verification', {
                'material_url': material, 'real_name': real, 'student_no': sno,
            })
            expect(s, b, 201, f'{nick} 提交认证')
            vid = b['verification']['id']
            s, b = admin.call('PATCH', f'/admin/verifications/{vid}',
                              {'status': 'approved', 'reason': ''})
            expect(s, b, 200, f'{nick} 认证审核')
        new_clients.append(c)
        print(f'[seed] 新用户就绪: {nick}')

    su, fan, gao = new_clients  # 自习室常客, 食堂测评员, 羽毛球搭子

    # 3. 确保真实测试账号存在（你在 App 上注册的账号；服务重启后由脚本重建）
    REAL_PHONE, REAL_NICK = '13158268668', 'hhh222'
    real_ids = []
    real_c = Client('xsnbb_csrf')
    s, b = real_c.call('POST', '/auth/login',
                       {'phone': REAL_PHONE, 'password': NEW_PASSWORD})
    if s != 200:
        s, b = real_c.call('POST', '/auth/sms-code',
                           {'phone': REAL_PHONE, 'purpose': 'register'})
        if s == 200:
            s, b = real_c.call('POST', '/auth/register', {
                'phone': REAL_PHONE, 'code': b['dev_code'], 'password': NEW_PASSWORD,
                'nickname': REAL_NICK, 'invite_code': INVITE,
            })
        if s != 201:
            print(f'[seed] 注意: {REAL_PHONE} 已存在且密码不是 {NEW_PASSWORD}，'
                  f'跳过该账号的私信演示')
            real_c = None
    if real_c is not None:
        s, me = real_c.call('GET', '/me')
        expect(s, me, 200, '真实账号查询资料')
        account = me['account']
        if not account.get('profile_done'):
            avatar = real_c.upload(make_avatar('#2E6BE6'), f'avatar-{REAL_PHONE}.png')
            s, b = real_c.call('PUT', '/me/profile', {
                'nickname': REAL_NICK, 'avatar': avatar, 'gender': '男',
                'real_name': '测试用户', 'student_no': '20230999',
                'class_name': '计算机2301',
            })
            expect(s, b, 200, '真实账号完善资料')
        if not account.get('verified'):
            material = real_c.upload(make_avatar('#999999'), f'material-{REAL_PHONE}.png')
            s, b = real_c.call('POST', '/me/verification', {
                'material_url': material, 'real_name': '测试用户',
                'student_no': '20230999',
            })
            expect(s, b, 201, '真实账号提交认证')
            vid = b['verification']['id']
            s, b = admin.call('PATCH', f'/admin/verifications/{vid}',
                              {'status': 'approved', 'reason': ''})
            expect(s, b, 200, '真实账号认证审核')
        real_ids = [account['id']]
        print(f'[seed] 真实账号就绪: {REAL_NICK} (id={account["id"]})')

    # 4. 幂等检查：王小雨是否已有标志帖子
    s, b = yu.call('GET', '/posts?mine=1')
    expect(s, b, 200, '查询王小雨帖子')
    if any(MARKER in (p.get('text') or '') for p in b.get('items', [])):
        print('[seed] 检测到已有演示内容，跳过内容创建（重造请先重启后端）')
    else:
        # 王小雨发 2 条新帖
        yu_posts = []
        for text, tags in MAIN_NEW_POSTS:
            s, b = yu.call('POST', '/posts', {'text': text, 'tags': tags})
            expect(s, b, 201, '王小雨发帖')
            yu_posts.append(b['post']['id'])
        # 王小雨的种子帖（id=3，高数笔记）也纳入互动
        s, b = yu.call('GET', '/posts?mine=1')
        seed_post = next((p['id'] for p in b['items']
                          if '高数期末复习' in (p.get('text') or '')), None)
        targets = {'N1': yu_posts[0], 'N2': yu_posts[1], 'P3': seed_post}
        print(f'[seed] 王小雨帖子: {targets}')

        # 新用户各发 1 帖
        for c, (text, tags) in zip(new_clients, NEW_USER_POSTS):
            s, b = c.call('POST', '/posts', {'text': text, 'tags': tags})
            expect(s, b, 201, '新用户发帖')

        # 点赞王小雨的帖子（9 次 → 9 条 like 通知）
        likes = [
            (li, 'P3'), (li, 'N1'), (li, 'N2'),
            (zhang, 'P3'), (zhang, 'N2'),
            (su, 'N1'),
            (fan, 'P3'), (fan, 'N1'),
            (gao, 'N2'),
        ]
        for c, key in likes:
            s, b = c.call('POST', f'/posts/{targets[key]}/like')
            expect(s, b, 200, '点赞')

        # 评论王小雨的帖子（6 条 → 6 条 comment 通知）
        comments = [
            (li, 'N1', '六点半也太狠了，我七点去只剩走廊座位。'),
            (zhang, 'N1', '三楼靠窗那排其实还有两个隐藏插座，一般人不知道。'),
            (su, 'N2', '带我一个，场地费 AA。'),
            (fan, 'N2', '打完球去二食堂，排骨窗口测评过了，靠谱。'),
            (gao, 'P3', '笔记已自取，谢谢学姐！'),
            (li, 'P3', '高数救命了，请你喝奶茶。'),
        ]
        for c, key, text in comments:
            s, b = c.call('POST', f'/posts/{targets[key]}/comments', {'text': text})
            expect(s, b, 201, '评论')

        # 王小雨评论李大壮的羽毛球帖（种子帖 id=2），李大壮回复 → reply 通知
        s, b = yu.call('POST', '/posts/2/comments', {'text': '报名！我带球。'})
        expect(s, b, 201, '王小雨评论李大壮')
        s, b = li.call('POST', '/posts/2/comments',
                       {'text': '好嘞，场地已订，周六见。', 'parent_id': b['comment']['id']})
        expect(s, b, 201, '李大壮回复')

        # 王小雨也给别人的帖子点赞，丰富首页
        yu.call('POST', '/posts/1/like')
        yu.call('POST', '/posts/2/like')

        # 3 个用户给王小雨发私信（各 1 条未读内置招呼）
        yu_id = 2
        for c in (li, zhang, gao):
            s, b = c.call('POST', '/direct-conversations', {'user_id': yu_id})
            expect(s, b, 201, '发起会话(王小雨)')
            s, b = c.call('POST', f'/direct-conversations/{b["item"]["id"]}/messages',
                          {'text': '你好，我想和你聊聊', 'system': True})
            expect(s, b, 201, '发送招呼(王小雨)')

        # 2 个用户给真实测试账号发私信 → 用户自己的账号也能看到角标
        for rid in real_ids:
            for c in (su, fan):
                s, b = c.call('POST', '/direct-conversations', {'user_id': rid})
                if s in (200, 201):
                    c.call('POST', f'/direct-conversations/{b["item"]["id"]}/messages',
                           {'text': '你好，我想和你聊聊', 'system': True})

        print('[seed] 点赞/评论/回复/私信全部完成')

    # 5. 汇报
    s, b = yu.call('GET', '/me/notifications')
    expect(s, b, 200, '查询王小雨未读')
    print(f'[seed] 王小雨 互动通知未读 = {b["unread"]}（共 {len(b["items"])} 条），私信未读 3')
    print('[seed] 演示主账号登录: 13800000001 / Demo12345')
    if real_ids:
        print(f'[seed] 你的账号（{REAL_PHONE} / {NEW_PASSWORD}）也已收到 2 条未读私信，'
              f'底栏角标应显示 2')


if __name__ == '__main__':
    main()
