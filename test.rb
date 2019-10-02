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

class Web_scraping
    attr_reader :all_product_urls_of_category
    attr_reader :goods

    def initialize(file_name, url) 
        @all_product_urls_of_category = []
        @file_name = file_name
        @url = url
        @goods = [['Name', 'Price', 'Image']];
    end

    def get_parsed_page(url)
        http = Curl.get(url)
        Nokogiri::HTML(http.body_str)
    end

    def add_in_all_product_urls_of_category_array(page_urls, all_urls_of_category)
        page_urls.each do |url_product| 
            all_urls_of_category.push(url_product)
        end
    end

    def geе_initial_data_from_the_requested_page
        doc = get_parsed_page(@url)
        @quantity_of_pages = doc.xpath('//div[contains(@id, "pagination_bottom")]//@href') 
        @product_urls_of_the_requested_page = doc.xpath('//a[contains(@class, "product_img_link")]//@href')
        add_in_all_product_urls_of_category_array(@product_urls_of_the_requested_page, @all_product_urls_of_category)
    end

    def get_product_urls_on_other_pages_if_they_exist
        if @quantity_of_pages[-2]
            total_quantity_pages_match = "#{@quantity_of_pages[-2]}".match(/[0-9]+/) 
            total_quantity_pages = "#{total_quantity_pages_match}".to_i

            p "Страница заданной категории содержит #{total_quantity_pages} страницы..."
            p "Скачиваем, парсим все страницы и получаем от них ссылки на страницы товаров..."
    
            for i in 2..total_quantity_pages do
                doc = get_parsed_page("#{@url}?p=#{i}")
                @product_urls_of_the_requested_page = doc.xpath('//a[contains(@class, "product_img_link")]//@href')
                add_in_all_product_urls_of_category_array(@product_urls_of_the_requested_page, @all_product_urls_of_category)
            end
        else 
            p "Страница заданной категории содержит 1 страницу..."
        end
    end

    def get_payload(array, page)
        doc = Nokogiri::HTML(page)

        product_name = "#{doc.xpath('//h1//text()')}".strip
        product_props = doc.xpath('//ul[contains(@class, "attribute_radio_list")]//span[@class="radio_label" or @class="price_comb"]//text()')
        urls_images = doc.xpath('//ul[contains(@id, "thumbs_list_frame")]//@href')

        product_sizes = [];
        product_prices = [];

        for i in 0..product_props.length - 1 do
            if i.even?
                product_sizes.push(product_props[i])
            else 
                product_prices.push(product_props[i])
            end
        end

        product_name_with_size = product_sizes.map { |size| "#{product_name} - #{size}"}
        product_prices_without_currency = product_prices.map { |price| "#{price}".gsub! /[^0-9.]/, '' }
        urls_images_with_reg_exp = urls_images.map { |urlImg| "#{urlImg}".gsub! 'thickbox', 'large' }

        for i in 0..product_sizes.length - 1 do
            item = [product_name_with_size[i], product_prices_without_currency[i], urls_images_with_reg_exp.join(', ')]
            array.push(item)
        end
    end

    def fetch_data_from_each_page_and_write_to_file
        responses = {}

        m = Curl::Multi.new

        @all_product_urls_of_category.each do |url|
            responses[url] = ""
            c = Curl::Easy.new(url) do |curl|
                curl.follow_location = true
                curl.on_body{|data| responses[url] << data; data.size } 
            end
            
            m.add(c)
        end

        m.perform

        @all_product_urls_of_category.each do|url|
            get_payload(@goods, responses[url])
        end

        File.write(@file_name, @goods.map(&:to_csv).join)
    end
end

p "Enter a file name:"
file_name = gets.chomp
p "Enter a link to the category page"
page_link = gets.chomp

instance = Web_scraping.new("#{file_name}.csv", page_link)
p "Скачиваем и парсим страницу #{page_link}..."
p "Получаем первоначальные данные с запрашиваемой категории: общее количество страниц со всеми товарами, адреса страниц товаров на 1 странице..."
instance.geе_initial_data_from_the_requested_page
p "Проверяем если общее количество страниц содержит больше чем 1..."
instance.get_product_urls_on_other_pages_if_they_exist
p "После получения всех ссылок на товары заданной категории, начинаем скачивать и парсить их страницы..."
p "Отбираем название, цену, размер и изображение товара..."
p "Корректируем полученные данные и записываем в файл #{file_name}.csv..."
instance.fetch_data_from_each_page_and_write_to_file