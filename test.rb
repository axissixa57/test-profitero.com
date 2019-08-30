require 'curb'
require 'nokogiri'
require 'csv'

# https://www.petsonic.com/huesos-para-perro/ - 1
# https://www.petsonic.com/snacks-piel-prensada/ - 5
# https://www.petsonic.com/barritas-para-perros/ - 11
# https://www.petsonic.com/libra/ - 15
# https://www.petsonic.com/snacks-higiene-dental-para-perros/ - 33
# https://www.petsonic.com/virbac/ - 65
# https://www.petsonic.com/royal-canin/ - 149

def fetchDataAndWriteToFile(fileName, url)
  http = Curl.get(url)

  puts "Скачиваем страницу #{url}..."

  doc = Nokogiri::HTML(http.body_str)

  puts "Парсим скачанную страницу..."

  quantityPagesText = doc.xpath('//div[contains(@id, "pagination_bottom")]//@href') 

  puts "Находим общее количество страниц категории с товарами..."

  urlsProductsOfPage = doc.xpath('//a[contains(@class, "product_img_link")]//@href')

  puts "Находим адреса страниц товаров на 1 странице..."

  allUrlsProductsOfCategory = [];

  puts "Добавляем их в массив, который будет хранить все адреса страниц товаров заданной категории..."

  urlsProductsOfPage.each do |urlProduct| 
    allUrlsProductsOfCategory.push(urlProduct)
  end

  puts "Проверяем если общее количество страниц содержит больше чем 1"

  if quantityPagesText[-2]
    totalQuantityPagesMatch = "#{quantityPagesText[-2]}".match(/[0-9]/)
    totalQuantityPages = "#{totalQuantityPagesMatch}".to_i

    puts "Страница заданной категории содержит #{totalQuantityPages} страниц"

    for i in 2..totalQuantityPages do
      puts "В скрипте используется sleep 3, что означает приостановление его выполнения на 3 секунды, чтобы не привлекать к себе внимание администраторов сайта!"

      sleep 3

      puts "Скачиваем страницу #{url}?p=#{i}..."

      http = Curl.get("#{url}?p=#{i}") 

      puts "Парсим скачанную страницу..."

      doc = Nokogiri::HTML(http.body_str)

      urlsProductsOfPage = doc.xpath('//a[contains(@class, "product_img_link")]//@href')

      puts "Находим адреса страниц товаров на #{i} странице и добавляем к массиву со всеми адресами товаров..."

      urlsProductsOfPage.each do |urlProduct| 
        allUrlsProductsOfCategory.push(urlProduct)
      end
    end
  else 
    puts "Страница заданной категории содержит 1 страницу..."
  end

  def fetchDataAndPushToArray(array, url)
    puts "Скачиваем страницу #{url}..."

    http = Curl.get(url)

    puts "Парсим скачанную страницу..."

    doc = Nokogiri::HTML(http.body_str)

    puts "Отбираем название, цену, размер и изображение товара..."

    productName = "#{doc.xpath('//h1//text()')}".strip
    productProps = doc.xpath('//ul[contains(@class, "attribute_radio_list")]//span//text()')
    urlsImages = doc.xpath('//ul[contains(@id, "thumbs_list_frame")]//@href')

    productSizes = [];
    productPrices = [];

    for i in 0..productProps.length - 1 do
      if i.even?
        productSizes.push(productProps[i])
      else 
        productPrices.push(productProps[i])
      end
    end

    puts "Корректируем полученные данные и добавляем в массив, которые будут записаны в файл..."

    productNamesWithSize = productSizes.map { |size| "#{productName} - #{size}"}
    productPricesWithoutCurrency = productPrices.map { |price| "#{price}".gsub! /[^0-9.]/, '' }
    urlsImagesWithRegExp = urlsImages.map { |urlImg| "#{urlImg}".gsub! 'thickbox', 'large' }

    for i in 0..productSizes.length - 1 do
      item = [productNamesWithSize[i], productPricesWithoutCurrency[i], urlsImagesWithRegExp.join(', ')]
      array.push(item)
    end
  end

  goods = [['Name', 'Price', 'Image']];

  puts "Далее проходимся по циклу в массиве с адресами товаров..."

  for i in 0..allUrlsProductsOfCategory.length - 1 do
    puts "В скрипте используется sleep 3, что означает приостановление его выполнения на 3 секунды, чтобы не привлекать к себе внимание администраторов сайта!"

    sleep 3

    fetchDataAndPushToArray(goods, "#{allUrlsProductsOfCategory[i]}".to_s)
  end

  puts "Записываем данные из массива в #{fileName} файл..."

  File.write(fileName, goods.map(&:to_csv).join)

  puts "Запись успешно завершена."
end

fetchDataAndWriteToFile('snacks-piel-prensada.csv', 'https://www.petsonic.com/snacks-piel-prensada/')