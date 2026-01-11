-- Создание базы данных
CREATE DATABASE IF NOT EXISTS tourism
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE tourism;

-- Таблица стран (справочник)
CREATE TABLE countries (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL
);

-- Таблица типов туров (справочник)
CREATE TABLE tour_types (
    id INT AUTO_INCREMENT PRIMARY KEY,
    type_name VARCHAR(100) NOT NULL
);

-- Таблица отелей (справочник)
CREATE TABLE hotels (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    country_id INT NOT NULL,
    stars INT,
    FOREIGN KEY (country_id) REFERENCES countries(id)
);

-- Таблица клиентов (справочник)
CREATE TABLE clients (
    id INT AUTO_INCREMENT PRIMARY KEY,
    full_name VARCHAR(150) NOT NULL,
    phone VARCHAR(20)
);

-- Таблица заказов (переменная информация)
CREATE TABLE orders (
    id INT AUTO_INCREMENT PRIMARY KEY,
    client_id INT NOT NULL,
    hotel_id INT NOT NULL,
    tour_type_id INT NOT NULL,
    order_date DATE NOT NULL,
    FOREIGN KEY (client_id) REFERENCES clients(id),
    FOREIGN KEY (hotel_id) REFERENCES hotels(id),
    FOREIGN KEY (tour_type_id) REFERENCES tour_types(id)
);
