from bs4 import BeautifulSoup
import sys

def extract_date(file_path):
    with open(file_path, 'r') as f:
        content = f.read()

    soup = BeautifulSoup(content, 'html.parser')
    element = soup.find('b', {'class': 'text-dark mr-2 font-20'})

    if element is not None:
        return element.text
    else:
        return None

if __name__ == "__main__":
    file_path = sys.argv[1]
    date = extract_date(file_path)
    if date is not None:
        print(date)
    else:
        print("No element found with the specified class.")
