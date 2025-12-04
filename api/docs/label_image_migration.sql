-- Добавление URL бирки и флага бирки для галереи одежды
ALTER TABLE clothes
    ADD COLUMN IF NOT EXISTS label_image_url VARCHAR;

ALTER TABLE clothes_gallery_images
    ADD COLUMN IF NOT EXISTS is_label BOOLEAN NOT NULL DEFAULT false;
