import pandas as pd
from tqdm import tqdm
from sqlalchemy import create_engine
from os import path
from links_scraper import get_all_links


if __name__ == "__main__":
    #con = create_engine('postgresql://localhost/postgres')
    con = create_engine('postgresql://postgres:123456@localhost')
    links = pd.read_sql("SELECT url FROM media_db where parsed = false and links is null and publish_date is not null", con=con)['url']
    existing_links = set(pd.read_sql("select url from media_db", con=con)['url'].values.tolist())
    if path.exists("bad_links.txt"):
        with open("bad_links.txt", "r") as f:
            bad_links = set([i.strip() for i in f.readlines()])
    existing_links = bad_links.union(existing_links)
    for link in tqdm(links):
        con.connect()
        new_links = get_all_links(link, existing_links=existing_links)
        if len(new_links) > 0:
            try:
                con.connect()
                sql = f"""UPDATE media_db SET links='{",".join(new_links)}' WHERE url='{link}'"""
                with con.begin() as conn:
                    conn.execute(sql)
            except:
                pass
