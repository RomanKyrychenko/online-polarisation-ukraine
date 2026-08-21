import requests
from urllib.parse import urlparse, urljoin
from bs4 import BeautifulSoup
from newspaper import Article, Config
import pandas as pd
from tqdm import tqdm
from sqlalchemy import create_engine, inspect
from os import path
import newspaper
from interruptingcow import timeout


class SingleSource(newspaper.Source):
    def __init__(self, articleURL):
        super(SingleSource, self).__init__("http://localhost")
        config = Config()
        config.request_timeout = 3
        self.articles = [newspaper.Article(url=articleURL, config=config)]


def get_domain(url: str) -> str:
    return urlparse(url).netloc


def is_valid(url: str) -> bool:
    """
    Checks whether `url` is a valid URL.
    """
    parsed = urlparse(url)
    return bool(parsed.netloc) and bool(parsed.scheme)


def get_all_links(url: str, content: str = None, existing_links: set = None) -> list:
    try:
        if content is None:
            content = requests.get(url, timeout=1).content
        soup = BeautifulSoup(content, "html.parser")
    except:
        return []
    domain_name = get_domain(url)
    urls = []
    for a_tag in soup.findAll("a"):
        href = a_tag.attrs.get("href")
        if href == "" or href is None:
            continue
        href = urljoin(url, href)
        parsed_href = urlparse(href)
        href = parsed_href.scheme + "://" + parsed_href.netloc + parsed_href.path
        if not is_valid(href):
            continue
        if href in urls:
            continue
        if domain_name not in href:
            continue
        urls.append(href)
    if existing_links is not None:
        urls = list(set(urls) - existing_links)
    return urls


def one_article(url: str) -> pd.DataFrame:
    try:
        article = Article(url)
        article.download()
        article.parse()
    except Exception:
        return None

    if article.publish_date is None:
        with open(f"bad_links.txt", "a") as f:
            print(article.url.strip(), file=f)
        return None

    res = pd.DataFrame({
        "source_url": article.source_url,
        "url": article.url,
        "title": article.title,
        "text": article.text,
        "authors": [article.authors],
        "publish_date": article.publish_date,
        "meta_img": article.meta_img,
        "meta_lang": article.meta_lang,
        "tags": [list(article.tags)],
        "meta_keywords": [article.meta_keywords],
        "meta_description": article.meta_description,
        "meta_data": article.meta_data,
        "images": [list(article.images)],
        "movies": [article.movies],
        "parsed": False,
        "links": [get_all_links(article.url, article.html)]
    }, index=[article.url])
    if res.shape[0] > 0:
        res["publish_date"] = pd.to_datetime(res["publish_date"], utc=True)
    return res


def multi_articles(urls: list,) -> list:
    sources = [SingleSource(articleURL=u) for u in urls]
    newspaper.news_pool.set(sources)
    newspaper.news_pool.join()
    resu = []
    for s in tqdm(sources, desc='articles scraping'):
        try:
            with timeout(3, exception=RuntimeError):
                try:
                    (s.articles[0]).parse()
                    if s.articles[0].publish_date is None:
                        with open(f"bad_links.txt", "a") as f:
                            print(s.articles[0].url.strip(), file=f)
                    else:
                        res = pd.DataFrame({
                            "source_url": s.articles[0].source_url,
                            "url": s.articles[0].url,
                            "title": s.articles[0].title,
                            "text": s.articles[0].text,
                            "authors": [s.articles[0].authors],
                            "publish_date": s.articles[0].publish_date,
                            "meta_img": s.articles[0].meta_img,
                            "meta_lang": s.articles[0].meta_lang,
                            "tags": [list(s.articles[0].tags)],
                            "meta_keywords": [s.articles[0].meta_keywords],
                            "meta_description": s.articles[0].meta_description,
                            "meta_data": s.articles[0].meta_data,
                            "images": [list(s.articles[0].images)],
                            "movies": [s.articles[0].movies],
                            "parsed": False,
                            "links": [get_all_links(s.articles[0].url, s.articles[0].html)]
                        }, index=[s.articles[0].url])
                        if res.shape[0] > 0:
                            res["publish_date"] = pd.to_datetime(res["publish_date"], utc=True)
                        resu.append(res)
                except:
                    pass
        except RuntimeError:
            pass
    return resu


def initial_scraper(url_adrs: list) -> pd.DataFrame:
    links = []
    for i in tqdm(url_adrs, desc='links scraping'):
        links.extend(get_all_links(i))
    articles = [one_article(i) for i in tqdm(links, desc='articles scraping')]
    df = pd.concat(articles)
    return df


url_adrs = [
    "https://russian.rt.com/",
    "http://life.ru",
    "http://www.rbc.ru/",
    "http://www.vedomosti.ru/",
    "https://www.gazeta.ru/",
    "http://lenta.ru",
    "http://www.interfax.ru/",
    "http://www.kommersant.ru/",
    "http://www.vesti.ru/",
    "https://ria.ru/",
    "http://izvestia.ru/",
    "http://tass.ru/",
    "http://mir24.tv/",
    "http://www.aif.ru/",
    "http://www.km.ru/",
    "http://fedpress.ru/",
    "http://www.kp.ru/",
    "http://tvzvezda.ru/",
    "http://ren.tv/",
    "http://ntv.ru",
]

url_adrs = ["https://" + get_domain(i) for i in url_adrs]


if __name__ == "__main__":
    #con = create_engine('postgresql://localhost/postgres')
    con = create_engine('postgresql://postgres:123456@localhost')
    if not inspect(con).has_table("media_db"):
        initial_df = initial_scraper(url_adrs)
        initial_df.to_sql("media_db", if_exists='append', con=con)

    while True:
        links = pd.read_sql("""
                select links from (
                SELECT * FROM (SELECT distinct replace(replace(unnest(string_to_array(a.links, ',')), '{', ''), '}', '') as "links" FROM (SELECT url, links
                FROM (
                SELECT *, ROW_NUMBER() OVER (PARTITION BY source_url ORDER BY publish_date) AS n
                FROM media_db where parsed = false and links is not null
                ) AS x
                WHERE n <= 20) a) t1 LEFT JOIN (select url from media_db) t2 ON t1.links = t2.url WHERE t2.url IS NULL) g
                """, con=con)['links'].values

        #links = []
        #for i in selection['links'].values:
        #    links.extend(i.replace('"', '').replace('{', '').replace('}', '').split(","))
        #links = list(set(links))
        links = [i for i in links if i != '']
        con.connect()
        sql = """
        UPDATE media_db SET parsed=True where url in (SELECT distinct url
        FROM (
        SELECT *, ROW_NUMBER() OVER (PARTITION BY source_url ORDER BY publish_date) AS n
        FROM media_db where parsed = false and links is not null
        ) AS x
        WHERE n <= 20)
        """
        with con.begin() as conn:
            try:
                conn.execute(sql)
            except TypeError:
                pass

        print("links count:", pd.read_sql("select count(*) from media_db", con=con)['count'][0])
        if path.exists("bad_links.txt"):
            with open("bad_links.txt", "r") as f:
                bad_links = set([i.strip() for i in f.readlines()])
        links = list(set(links) - bad_links)
        if len(links) > 0:
            if len(links) < 3:
                articles = [one_article(i) for i in tqdm(links, desc='articles scraping')]
            else:
                articles = multi_articles(links)
            if not all([i is None for i in articles]):
                df = pd.concat(articles)
                df.to_sql("media_db", if_exists='append', con=con)

"""
pd.read_sql("
        SELECT source_url, publish_date
        FROM (
        SELECT *, ROW_NUMBER() OVER (PARTITION BY source_url ORDER BY publish_date) AS n 
        FROM media_db where parsed = false
        ) AS x
        WHERE n = 1
        ", con=con)
        
pd.read_sql("SELECT source_url, count(*) FROM media_db group by source_url", con=con)

pd.read_sql("SELECT source_url, count(*) FROM media_db where parsed = false group by source_url", con=con)

def add_column(engine, table_name, column):
    column_name = column.compile(dialect=engine.dialect)
    column_type = column.type.compile(engine.dialect)
    engine.execute('ALTER TABLE %s ADD COLUMN %s %s' % (table_name, column_name, column_type))

from sqlalchemy import Column, String

column = Column('links', String(10000), primary_key=True)
add_column(con, 'media_db', column)


if path.exists("bad_links.txt"):
    with open("bad_links.txt", "r") as f:
        bad_links = set([i.strip() for i in f.readlines()])
"""
