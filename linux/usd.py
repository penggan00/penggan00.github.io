import yfinance as yf
import requests
import os
from dotenv import load_dotenv
import time
from datetime import datetime, timedelta
import pytz
from lunarcalendar import Converter, Solar, Lunar
import pandas as pd

# 加载环境变量
load_dotenv()

TELEGRAM_BOT_TOKEN = os.getenv("TELEGRAM_API_KEY")
TELEGRAM_CHAT_ID = os.getenv("TELEGRAM_CHAT_ID")
JUHE_STOCK_KEY = os.getenv("JUHE_STOCK_KEY")
LIAO_STOCK_KEY = os.getenv("LIAO_STOCK_KEY")
QWEATHER_API_KEY = os.getenv("QWEATHER_API_KEY")
QWEATHER_API_HOST = os.getenv("QWEATHER_API_HOST")

# 配置参数
CITIES = {
    "南昌": os.getenv("CITY_NANCHANG", "101240101"),
    "萍乡": os.getenv("CITY_PINGXIANG", "101240901")
}
# 聚合数据API
STOCK_ETF = [
        ('sh510300', '沪深300'),
    #    ('sh588000', '科创x50')
]
# 聚合数据API
STOCK_LIST = [
        ('sz300059', '东方财富'),
        ('sz302132', '中航成飞'),
        ('sz002371', '北方华创'),
        ('sz002415', '海康威视'),
        ('sz000651', '格力电器'),
        ('sz000823', '超声电子'),
        ('sz000725', '京东方A'),
        ('sz300065', '海兰信'),
        ('sz002594', '比亚迪')
]
# yfinance商品数据
COMMODITY_SYMBOLS = {
    "DX=F": "美元指数",
    "GC=F": "黄金",
    "BZ=F": "原油"
}

class MarketConfig:
    USA_API = 'http://web.juhe.cn/finance/stock/usa'
    HK_API = 'http://web.juhe.cn/finance/stock/hk'  # 新增香港API
    USA_INDEXES = {
        '纳斯达克': {'code': 'IXIC', 'unit': ''},
        '道琼斯': {'code': 'DJI', 'unit': ''}
    }
    HK_INDEXES = {
        '恒生指数': {'code': 'HSI', 'unit': ''}  # 新增恒生指数配置
    }
# ================== 新增服务类 ==================
class StockService:
    @staticmethod
    def fetch_data(api_url, params):
        try:
            response = requests.get(api_url, params=params, timeout=10)
            if response.status_code == 200:
                result = response.json()
                if result.get('error_code') == 0:
                    return result.get('result')
            return None
        except Exception as e:
            print(f"请求异常: {e}")
            return None

    @classmethod
    def get_usa_data(cls, gid):
        params = {'key': JUHE_STOCK_KEY, 'gid': gid.lower()}
        return cls.fetch_data(MarketConfig.USA_API, params)
    # 新增香港数据获取方法
    @classmethod
    def get_hk_data(cls, num):
        params = {'key': JUHE_STOCK_KEY, 'num': num}
        return cls.fetch_data(MarketConfig.HK_API, params)
    
class DataProcessor:
    @staticmethod
    def parse_usa_index(data):
        if not data or not isinstance(data, list) or len(data) == 0:
            return None
        index_data = data[0].get('data', {})
        
        # 增强数值处理
        def format_number(value, is_percent=False):
            try:
                num = float(str(value).replace('%', ''))
                if is_percent:
                    return round(num, 2)
                return round(num, 2)  # 强制保留2位小数
            except:
                return None

        return {
            'price': format_number(index_data.get('lastestpri')),
            'change_percent': format_number(index_data.get('limit'), True),
            'change_point': format_number(index_data.get('uppic')),
            'unit': '',
            'is_positive': format_number(index_data.get('uppic')) >= 0  # 新增正负判断
        }
 # 新增香港数据解析方法
    @staticmethod
    def parse_hk_index(data):
        if not data or not isinstance(data, list) or len(data) == 0:
            return None
            
        # 获取恒生指数数据
        hsi_data = data[0].get('hengsheng_data', {})
        
        # 增强数值处理
        def format_number(value, is_percent=False):
            try:
                num = float(str(value).replace('%', ''))
                if is_percent:
                    return round(num, 2)
                return round(num, 2)
            except:
                return None

        return {
            'price': format_number(hsi_data.get('lastestpri')),
            'change_percent': format_number(hsi_data.get('limit'), True),
            'change_point': format_number(hsi_data.get('uppic')),
            'unit': '',
            'is_positive': format_number(hsi_data.get('uppic')) >= 0
        }
# ================== 新增香港数据处理类 ==================
# 设置时区
hongkong = pytz.timezone('Asia/Hong_Kong')
BASE_DATE = datetime(2024, 12, 6, tzinfo=hongkong)

# Markdown转义
def escape_markdown(text):
    for char in ['_', '*', '[', '`']:
        text = text.replace(char, f'\\{char}')
    return text

def format_price(price, is_etf=False):
    return f"{price:.3f}" if is_etf else f"{price:.2f}"

def send_to_telegram(message):
    url = f"https://api.telegram.org/bot{TELEGRAM_BOT_TOKEN}/sendMessage"
    payload = {
        "chat_id": TELEGRAM_CHAT_ID,
        "text": message,
        "parse_mode": "Markdown",
        "disable_web_page_preview": True
    }
    try:
        requests.post(url, json=payload, timeout=10)
    except:
        pass

def get_reminders():
    now = datetime.now(hongkong)
    solar_today = Solar(now.year, now.month, now.day)
    messages = []

    # 1. 日常提醒
    messages.append('💊💊💊')

    # 2. 每10天通行证续签
    days_since_base = (now - BASE_DATE).days
    if days_since_base % 10 == 0:
        messages.append('🔄 续签通行证！')

    # 3. 固定日期年提醒
    annual_reminders = {
        (3, 1): "🚗 小车打腊",
        (5, 1): "📝 从业资格证年审",
        (8, 1): "📋 cloudcone-VPS",
        (10, 5): "💍 结婚周年",
        (11, 26): "✈️ 离开,彭昊一",
        (12, 1): "📋 小车年检保险"
    }
    for (month, day), msg in annual_reminders.items():
        if now.month == month and now.day == day:
            messages.append(msg)

    # 4. 特定年份提醒
    specific_year_reminders = {
        (2031, 4, 5): "🔄 建行银行卡",
        (2026, 10, 5): "💎 结婚20周年",
        (2027, 5, 1): "🔄 女儿医保卡",
        (2027, 5, 11): "🔄 爸爸换身份证",
        (2028, 6, 1): "🔄 招商银行卡",
        (2030, 11, 1): "🔄 中国信用卡",
        (2037, 3, 1): "🆔 换身份证"
    }
    for (y, m, d), msg in specific_year_reminders.items():
        if now.year == y and now.month == m and now.day == d:
            messages.append(msg)

    # 5. 每月云闪付提醒
    if now.day == 1:
        messages.append('1号提醒，云闪付，拍照，血压')

    # 6. 农历生日处理
    lunar_today = Converter.Solar2Lunar(solar_today)
    lunar_birthdays = {
        (2, 1): "🎂 杜根华，生日",
        (2, 28): "🎂 彭佳文，生日",
        (3, 11): "🎂 刘裕萍，生日",
        (4, 12): "🎂 彭绍莲，生日",
        (4, 16): "🎂 杜俊豪，生日",
        (4, 20): "🎂 邬思，生日",
        (4, 27): "🎂 彭博，生日",
        (5, 5): "🎂 周子君，生日",
        (6, 26): "🎂 奶奶，生日",      
        (8, 17): "🎂 邬启元，生日",
        (8, 29): "🎂 黄文香，生日",
        (10, 9): "🎂 彭付生，生日",
        (10, 18): "🎂 彭贝娜，生日",
        (11, 12): "🎂 彭辉，生日",
        (11, 22): "🎂 彭干，生日",
        (12, 1): "🎂 彭昊一，生日",
        (12, 29): "🎂 彭世庆，生日"
    }
    for (month, day), msg in lunar_birthdays.items():
        if lunar_today.month == month and lunar_today.day == day:
            messages.append(msg)

    return messages


def get_tomorrow_rain_info():
    """获取明日降雨信息（优化增强版）"""
    # 获取北京时间明日日期（和风天气API使用本地时间）
    beijing_tz = pytz.timezone('Asia/Shanghai')
    tomorrow_date = (datetime.now(beijing_tz) + timedelta(days=1)).strftime("%Y-%m-%d")
    rainy_cities = []
    
    # 扩展的降雨关键词（覆盖中英文及常见降雨类型）
    RAIN_KEYWORDS = {
        'cn': ["雨", "阵雨", "雷雨", "小雨", "中雨", "大雨", "暴雨", "毛毛雨", "冰雹"],
        'en': ["rain", "shower", "storm", "drizzle", "thunderstorm"]
    }

    for city_name, city_id in CITIES.items():
        try:
            # 请求3天天气预报
            url = f"https://{QWEATHER_API_HOST}/v7/weather/3d"
            params = {"location": city_id, "key": QWEATHER_API_KEY}
            response = requests.get(url, params=params, timeout=10)
            response.raise_for_status()  # 触发HTTP错误异常
            
            data = response.json()
            
            # 调试日志（需手动启用）
            # print(f"[DEBUG] {city_name} API响应: {json.dumps(data, indent=2, ensure_ascii=False)}")
            
            if data.get("code") == "200":
                # 查找明日天气预报
                for daily_data in data["daily"]:
                    if daily_data["fxDate"] == tomorrow_date:
                        # 合并白天和夜间天气描述（兼容中英文大小写）
                        weather_text = "".join([
                            daily_data.get("textDay", "").lower().strip(),
                            daily_data.get("textNight", "").lower().strip()
                        ])
                        
                        # 判断降雨条件（支持中英文混合匹配）
                        has_rain = any(
                            keyword in weather_text 
                            for lang in RAIN_KEYWORDS.values() 
                            for keyword in lang
                        )
                        
                        # 构造降雨信息（包含白天/夜间完整描述）
                        if has_rain:
                            report = (
                                f"*{city_name}：{daily_data['textDay']}转{daily_data['textNight']}，"
                                f"气温 {daily_data['tempMin']}~{daily_data['tempMax']}℃*"
                            )
                            rainy_cities.append(report)
                        break
                else:
                    print(f"[WARNING] {city_name} 未找到明日天气数据")
            else:
                print(f"[API ERROR] {city_name} 请求失败: {data.get('code')}-{data.get('message')}")
                
        except requests.exceptions.RequestException as e:
            print(f"[NETWORK ERROR] 获取{city_name}天气失败: {str(e)}")
        except KeyError as e:
            print(f"[DATA ERROR] {city_name} 数据解析异常，缺少字段: {str(e)}")
    
    # 返回格式化结果（有降雨信息时）
    if rainy_cities:
        return "\n".join(rainy_cities) + "\n"
    return ""

def get_financial_data(symbol, name):
    """商品数据获取函数（修正版）"""
    try:
        ticker = yf.Ticker(symbol)
        data = ticker.history(period="2d")
        if len(data) >= 2:
            price = data['Close'].iloc[-1]
            prev_close = data['Close'].iloc[-2]
            change = price - prev_close
            percent = (change / prev_close) * 100
            
            emoji = "🔴" if change > 0 else "🔵"
            sign = "+" if change > 0 else ""
            
            # 直接使用标准价格格式（无ETF判断）
            return (
                f"{emoji} {escape_markdown(name)}: *{escape_markdown(format_price(price))}* "
                f"({sign}{escape_markdown(format_price(change))}, "
                f"{sign}{escape_markdown(f'{percent:.2f}%')})\n"
            )
    except Exception as e:
        print(f"获取商品 {name} 失败: {str(e)}")  # 仅打印日志，不返回错误
    return ""

def get_usd_cny_data():
    """
    使用聚合数据外汇API获取USD/CNY汇率数据
    """
    apiUrl = 'http://web.juhe.cn/finance/exchange/frate'
    apiKey = os.getenv("JUHE_FOREX_KEY")
    params = {
        'key': apiKey,
        'type': '',
    }
    
    try:
        response = requests.get(apiUrl, params=params, timeout=10)
        response.raise_for_status()  # 触发HTTP错误异常
        
        data = response.json()
        if data.get('error_code') != 0:
            print(f"API返回错误：{data.get('reason')}")
            return None
        
        # 解析数据结构
        result_list = data.get('result', [])
        if not result_list or not isinstance(result_list, list):
            return None
            
        forex_data = result_list[0].get('data8', {})
        if not forex_data:
            return None
        
        # 提取并转换数值
        price = float(forex_data['closePri'])
        change_point = float(forex_data['diffAmo'])
        change_percent = float(forex_data['diffPer'].replace('%', ''))
        
        return {
            'price': price,
            'change_percent': change_percent,
            'change_point': change_point
        }
        
    except requests.exceptions.RequestException as e:
        print(f"外汇API请求失败: {str(e)}")
    except (KeyError, IndexError, ValueError) as e:
        print(f"数据解析异常: {str(e)}")
    
    return None

def get_usd_cny_formatted():
    """格式化USD/CNY数据，保持原有消息格式"""
    data = get_usd_cny_data()
    if data:
        is_positive = data['change_point'] >= 0
        emoji = "🔴" if is_positive else "🔵"
        sign = "+" if is_positive else ""
        
        # 格式化数值（保留4位小数）
        price_str = f"{data['price']:.2f}"
        percent_str = f"{abs(data['change_percent']):.2f}%"
        point_str = f"{abs(data['change_point']):.2f}"
        
        # Markdown转义处理
        price_str = escape_markdown(price_str)
        percent_str = escape_markdown(f"{sign}{percent_str}")
        point_str = escape_markdown(f"{sign}{point_str}")
        
        return f"{emoji} USD/CNY: *{price_str}* ({percent_str}, {point_str})\n"
    return ""

def get_usa_index(index_code, index_name):
    """使用聚合数据获取美股指数（优化版）"""
    try:
        time.sleep(1)  
        raw_data = StockService.get_usa_data(index_code)
        parsed_data = DataProcessor.parse_usa_index(raw_data)
        
        if not parsed_data or None in parsed_data.values():
            return f"⚠️ 获取 {escape_markdown(index_name)} 数据失败\n"
  
        # 修改格式化方式（去掉数值自身的符号）
        price_str = f"{parsed_data['price']:.2f}" if parsed_data['price'] is not None else 'N/A'
        change_point_str = f"{abs(parsed_data['change_point']):.2f}" if parsed_data['change_point'] is not None else 'N/A'
        change_percent_str = f"{abs(parsed_data['change_percent']):.2f}%" if parsed_data['change_percent'] is not None else 'N/A'

        # 符号处理优化
        is_positive = parsed_data.get('is_positive', False)
        emoji = "🔴" if is_positive else "🔵"
        sign = "+" if is_positive else "-"  # 统一符号来源
        
        return (
            f"{emoji} {escape_markdown(index_name)}: *{escape_markdown(price_str)}* "
            f"(*{sign}{escape_markdown(change_percent_str)}*, "
            f"{sign}{escape_markdown(change_point_str)})\n"
        )
    except Exception as e:
        print(f"获取美股指数异常: {str(e)}")
        return ""
    
# 聚合数据获取A股数据
def get_cn_stock(gid, name):
    params = {"key": LIAO_STOCK_KEY, "gid": gid}
    try:
        time.sleep(1)  
        response = requests.get("http://web.juhe.cn/finance/stock/hs", params=params, timeout=10)
        data = response.json()
        
        if data.get('error_code') == 0:
            result = data['result']
            if isinstance(result, list):
                stock_data = result[0]['data']
                price = float(stock_data['nowPri'])
                change = float(stock_data['increase'])
                percent = float(stock_data['increPer'])
            else:
                price = float(result['nowpri'])
                change = float(result['increase'])
                percent = float(result['increPer'])
            
            emoji = "🔴" if change > 0 else "🔵"
            sign = "+" if change > 0 else ""
            return f"{emoji} {escape_markdown(name)}: *{escape_markdown(format_price(price))}* (*{sign}{escape_markdown(f'{percent:.2f}')}*%, {sign}{escape_markdown(format_price(change))})\n"
    except:
        pass
    return ""

def get_ci_stock(gid, name):
    params = {"key": JUHE_STOCK_KEY, "gid": gid}
    try:
        time.sleep(1)  
        response = requests.get("http://web.juhe.cn/finance/stock/hs", params=params, timeout=10)
        data = response.json()
        
        if data.get('error_code') == 0:
            result = data['result']
            if isinstance(result, list):
                stock_data = result[0]['data']
                price = float(stock_data['nowPri'])
                change = float(stock_data['increase'])
                percent = float(stock_data['increPer'])
            else:
                price = float(result['nowpri'])
                change = float(result['increase'])
                percent = float(result['increPer'])
            
            emoji = "🔴" if change > 0 else "🔵"
            sign = "+" if change > 0 else ""
            return f"{emoji} {escape_markdown(name)}: *{escape_markdown(format_price(price))}* (*{sign}{escape_markdown(f'{percent:.2f}')}*%, {sign}{escape_markdown(format_price(change))})\n"
    except:
        pass
    return ""

def get_etf_stock(gid, name):
    params = {"key": JUHE_STOCK_KEY, "gid": gid}
    try:
        time.sleep(1)  
        response = requests.get("http://web.juhe.cn/finance/stock/hs", params=params, timeout=10)
        data = response.json()
        
        if data.get('error_code') == 0:
            result = data['result']
            if isinstance(result, list):
                stock_data = result[0]['data']
                price = float(stock_data['nowPri'])
                change = float(stock_data['increase'])
                percent = float(stock_data['increPer'])
            else:
                price = float(result['nowpri'])
                change = float(result['increase'])
                percent = float(result['increPer'])
            
            emoji = "🔴" if change > 0 else "🔵"
            sign = "+" if change > 0 else ""
        return (
            f"{emoji} {escape_markdown(name)}: *{escape_markdown(f'{price:.3f}')}* "  # 修改为.3f
            f"(*{sign}{escape_markdown(f'{percent:.2f}')}%*, "
            f"{sign}{escape_markdown(f'{change:.3f}')})\n"  # 修改为.3f
        )
    except:
        pass
    return ""

def get_hk_index(index_code, index_name):
    """获取香港恒生指数数据"""
    try:
        time.sleep(1)  
        raw_data = StockService.get_hk_data(index_code)
        parsed_data = DataProcessor.parse_hk_index(raw_data)
        
        if not parsed_data or None in parsed_data.values():
            return ""
  
        # 格式化数据
        price_str = f"{parsed_data['price']:.2f}" if parsed_data['price'] is not None else 'N/A'
        change_point_str = f"{abs(parsed_data['change_point']):.2f}" if parsed_data['change_point'] is not None else 'N/A'
        change_percent_str = f"{abs(parsed_data['change_percent']):.2f}%" if parsed_data['change_percent'] is not None else 'N/A'

        # 符号处理
        is_positive = parsed_data.get('is_positive', False)
        emoji = "🔴" if is_positive else "🔵"
        sign = "+" if is_positive else "-"
        
        return (
            f"{emoji} {escape_markdown(index_name)}: *{escape_markdown(price_str)}* "
            f"(*{sign}{escape_markdown(change_percent_str)}*, "
            f"{sign}{escape_markdown(change_point_str)})\n"
        )
    except Exception as e:
        print(f"获取香港指数异常: {str(e)}")
        return ""
def main():
    message_parts = []
    
    # 日期信息
    now = datetime.now(hongkong)
    weekday_map = {0: "一", 1: "二", 2: "三", 3: "四", 4: "五", 5: "六", 6: "日"}
    message_parts.append(f"*{now.year}年{now.month}月{now.day}日  星期{weekday_map[now.weekday()]}*  ")
    
    # 第二行：农历日期
    solar_today = Solar(now.year, now.month, now.day)
    lunar_today = Converter.Solar2Lunar(solar_today)
    lunar_month_names = ["正月", "二月", "三月", "四月", "五月", "六月", 
                        "七月", "八月", "九月", "十月", "冬月", "腊月"]
    lunar_day_names = ["初一", "初二", "初三", "初四", "初五", "初六", "初七", "初八", "初九", "初十",
                      "十一", "十二", "十三", "十四", "十五", "十六", "十七", "十八", "十九", "二十",
                      "廿一", "廿二", "廿三", "廿四", "廿五", "廿六", "廿七", "廿八", "廿九", "三十"]
    
    message_parts.append(f"  农历{lunar_month_names[lunar_today.month-1]}{lunar_day_names[lunar_today.day-1]}\n\n")
    
    # 提醒事项
    reminders = get_reminders()
    if reminders:
        message_parts.extend([f"• *{reminder}*\n" for reminder in reminders])
    
    # 天气信息
    rain_info = get_tomorrow_rain_info()
    if rain_info:
        message_parts.append(rain_info)
    
    message_parts.append("--------------------------------------\n")
    
    # 获取主要指数
    message_parts.append(get_ci_stock('sh000001', '上证指数'))
    message_parts.append(get_ci_stock('sz399001', '深证成指'))
    message_parts.append(get_hk_index('HSI', '恒生指数'))
    message_parts.append(get_usa_index('IXIC', '纳斯达克'))  
    message_parts.append(get_usa_index('DJI', '道琼斯'))     
    
    message_parts.append("--------------------------------------\n")
    # 聚合数据API获取ETF数据
    for code, name in STOCK_ETF:
        message_parts.append(get_etf_stock(code, name))
    # 聚合数据API获取A股数据
    for code, name in STOCK_LIST:
        message_parts.append(get_cn_stock(code, name))

    message_parts.append("--------------------------------------\n")
    
    # 获取商品数据
    for symbol, name in COMMODITY_SYMBOLS.items():
        message_parts.append(get_financial_data(symbol, name))
    # 单独添加USD/CNY数据
    message_parts.append(get_usd_cny_formatted())
    # 发送消息
    full_message = "".join([str(part) for part in message_parts if part])
    send_to_telegram(full_message)

if __name__ == "__main__":
    main()