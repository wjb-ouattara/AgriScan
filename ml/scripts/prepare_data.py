import json
import os

from langchain_text_splitters import RecursiveCharacterTextSplitter

import pdfplumber


def extract_text_from_pdf(pdf_path):
    print(f"📄 Lecture sémantique du PDF : {pdf_path}")
    full_text = ""

    with pdfplumber.open(pdf_path) as pdf:
        for page_num, page in enumerate(pdf.pages, 1):
            # 1. On extrait les tableaux de la page
            tables = page.extract_tables()

            # 2. On extrait le texte brut de la page
            page_text = page.extract_text()

            if page_text:
                full_text += f"\n--- Page {page_num} ---\n"
                full_text += page_text + "\n"

            # 3. S'il y a des tableaux, on les formate proprement en texte
            if tables:
                full_text += "\n[TABLEAUX DÉTECTÉS SUR CETTE PAGE] :\n"
                for table in tables:
                    for row in table:
                        # On nettoie les None et on sépare les colonnes par des " | "
                        clean_row = [str(cell).strip() if cell is not None else "" for cell in row]
                        full_text += " | ".join(clean_row) + "\n"
                    full_text += "\n"

    return full_text


def chunk_text(text):
    # Découpe le texte intelligemment en respectant les fins de phrases et paragraphes
    text_splitter = RecursiveCharacterTextSplitter(
        chunk_size=1000,
        chunk_overlap=100,  # Chevauchement pour ne pas perdre le contexte entre deux morceaux
        length_function=len
    )
    return text_splitter.split_text(text)


def main():
    pdf_folder = "ml/data/pdfs/"  # Mets tes PDF ici
    output_json_path = "./data/raw_chunks.json"

    os.makedirs(pdf_folder, exist_ok=True)

    all_chunks = []
    chunk_id = 1

    # Parcourir tous les PDF du dossier
    pdf_files = [f for f in os.listdir(pdf_folder) if f.endswith('.pdf')]

    if not pdf_files:
        print(f"⚠️ Aucun fichier PDF trouvé dans {pdf_folder}. Dépose tes documents dedans !")
        return

    for file_name in pdf_files:
        pdf_path = os.path.join(pdf_folder, file_name)
        raw_text = extract_text_from_pdf(pdf_path)
        chunks = chunk_text(raw_text)

        for chunk in chunks:
            all_chunks.append({
                "id": f"CHUNK_{chunk_id:04d}",
                "source": file_name,
                "raw_content": chunk.strip()
            })
            chunk_id += 1

    with open(output_json_path, "w", encoding="utf-8") as f:
        json.dump(all_chunks, f, ensure_ascii=False, indent=2)

    print(f"✅ Terminé ! {len(all_chunks)} morceaux sauvegardés dans {output_json_path}")


if __name__ == "__main__":
    main()