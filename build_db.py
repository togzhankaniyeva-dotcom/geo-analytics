import sqlite3
import pandas as pd
from pathlib import Path

# Пути к папкам
RAW_DATA_PATH = Path("data/raw")
DB_PATH = Path("data/geo.db")

def build_database():
    print("Начинаем сборку базы данных...")
    
    # Подключаемся к SQLite (файл создастся автоматически)
    conn = sqlite3.connect(DB_PATH)
    
    # Словарь: название таблицы -> имя файла
    files = {
        "customers": "customers.csv",
        "cards": "cards.csv",
        "devices": "devices.csv",
        "merchants": "merchants.csv",
        "transactions": "transactions.csv"
    }
    
    for table_name, file_name in files.items():
        file_path = RAW_DATA_PATH / file_name
        if file_path.exists():
            df = pd.read_csv(file_path)
            # Загружаем в базу (если таблица есть, перезаписываем)
            df.to_sql(table_name, conn, if_exists="replace", index=False)
            print(f"✅ Таблица '{table_name}' загружена ({len(df)} строк)")
        else:
            print(f"❌ Файл {file_name} не найден в {RAW_DATA_PATH}")
            
    # Создаем индексы для ускорения SQL-запросов (поиск по ID)
    cur = conn.cursor()
    try:
        cur.execute("CREATE INDEX IF NOT EXISTS idx_tx_customer ON transactions(customer_id);")
        cur.execute("CREATE INDEX IF NOT EXISTS idx_tx_merchant ON transactions(merchant_id);")
        cur.execute("CREATE INDEX IF NOT EXISTS idx_tx_ts ON transactions(timestamp);")
    except Exception as e:
        print(f"Предупреждение при создании индексов: {e}")
        
    conn.commit()
    conn.close()
    print(f"\n🎉 База данных успешно собрана и сохранена в {DB_PATH}")

if __name__ == "__main__":
    build_database()