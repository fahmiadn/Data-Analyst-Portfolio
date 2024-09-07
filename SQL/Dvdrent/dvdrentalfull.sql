-- 1. Customer behavior and perferences insights
--- Q1: Which genres of movies are most popular among the customers? 

WITH table1 AS (SELECT c.name , r.rental_id
				FROM	category c 
				JOIN film_category fc ON c.category_id = fc.category_id
				JOIN inventory i  ON fc.film_id = i.film_id
				JOIN rental r ON i.inventory_id = r.inventory_id)
SELECT name AS genre, count(rental_id) AS total_rental
FROM	table1
GROUP BY genre
ORDER BY total_rental DESC
LIMIT 5;
SELECT r.inventory_id, to_char(rental_date, 'month') 
FROM rental r 
WHERE EXTRACT(MONTH FROM rental_date) = 2;

SELECT r.inventory_id, date_trunc('month', rental_date) 
FROM rental r 
WHERE EXTRACT(MONTH FROM rental_date) = 2;

--- Q2: Whose actor has shined brightest in the eyes of our customers?
WITH table1 AS	(SELECT 
					CONCAT(a.first_name, ' ', a.last_name) AS actor_name,
					COUNT(r.rental_id) AS total_rental
				 FROM actor a
				 JOIN film_actor fa ON a.actor_id = fa.actor_id
				 JOIN inventory i ON fa.film_id = i.film_id
				 JOIN rental r ON i.inventory_id = r.inventory_id
				 GROUP BY actor_name)
SELECT 
	actor_name, total_rental
FROM table1
ORDER BY total_rental DESC 
LIMIT 5;

-- 2. Analyzing rental patterns
--- Q1: How often is the DVD rented per month?
SELECT 
	TO_CHAR(rental_date, 'month') AS rental_month,
	COUNT(*) AS total_rentals
FROM rental
GROUP BY rental_month
ORDER BY rental_month;
   
--- Q2: What is the most popuplar film and its average rental duration?
SELECT 
	f.film_id, f.title, COUNT(r.rental_id) AS total_rental,
	round(AVG(EXTRACT (DAY FROM r.return_date - r.rental_date)),2) AS avg_duration
FROM 
	film f
JOIN inventory i ON f.film_id = i.film_id
JOIN rental r ON i.inventory_id = r.inventory_id
GROUP BY f.film_id
ORDER BY total_rental DESC
LIMIT 10;

--- Q3: What are the peak rental times overall?				  
SELECT
    EXTRACT(HOUR FROM rental_date) AS rental_hour,
    COUNT(*) AS total_rentals
FROM
    rental
GROUP BY rental_hour
ORDER BY total_rentals DESC
LIMIT 5;

-- 3. Demographic
--- Q1: Where are the customer from? 
SELECT 
	DISTINCT cy.country,COUNT(r.customer_id) AS total_customers
FROM 
	customer c
JOIN address a ON c.address_id = a.address_id
JOIN city ci ON a.city_id = ci.city_id 
JOIN country cy ON ci.country_id = cy.country_id 
JOIN rental r ON c.customer_id = r.customer_id 
GROUP BY cy.country
ORDER BY cy.country ASC ; 


-- 4. Movie Performance
--- Q1: How much the gross revenue for comedy movies in Juni-Agustus 2005? 
SELECT
  	TO_CHAR(rental_date,'Month')  AS rental_month,
	SUM(payment.amount) AS gross_revenue
FROM 
	rental r
JOIN inventory i  ON r.inventory_id = i.inventory_id 
JOIN film_category fc ON i.film_id = fc.film_id 
JOIN category c ON fc.category_id = c.category_id 
JOIN payment ON r.rental_id = payment.rental_id
WHERE c."name" = 'Comedy'
    AND rental_date BETWEEN '2005-06-01' AND '2006-08-31'
GROUP BY rental_month
ORDER BY rental_month;
   

-- 5. SETTING A DISCOUNT
--- Q1: Determine which day has the lowest sales in order to decide which day we will hold a discount.
SELECT
    TO_CHAR(r.rental_date, 'Day') AS day_name,
    COUNT(*) AS total_rentals
FROM
    rental r
GROUP BY day_name
ORDER BY total_rentals DESC;

--- Q2: Determine which genres are popular, moderately popular, and unpopular in order to decide the amount of discount that will be given.
WITH RankedGenres AS (
    SELECT
        c.category_id,
        COUNT(r.rental_id) AS total_rental,
        NTILE(3) OVER (ORDER BY COUNT(r.rental_id) DESC) AS genre_rank
    FROM
        category c
    JOIN film_category fc ON c.category_id = fc.category_id
    JOIN inventory i ON fc.film_id = i.film_id
    JOIN rental r ON i.inventory_id = r.inventory_id
    GROUP BY c.category_id
),
DiscountedGenres AS (
    SELECT
        rg.category_id,
        c.name AS category_name,
        CASE
        		WHEN genre_rank = 1 THEN 'Popular'
        		WHEN genre_rank = 2 THEN 'Moderate'
        		ELSE 'Unpopular'
    	  END AS genre_class,
        CASE
            WHEN rg.genre_rank = 1 THEN 0.05  -- 5% discount for Popular
            WHEN rg.genre_rank = 2 THEN 0.10  -- 10% discount for Moderate
            ELSE 0.15  -- 15% discount for Unpopular
        END AS discount
    FROM
        RankedGenres rg
    INNER JOIN category c ON rg.category_id = c.category_id
)
SELECT
    category_id,
    category_name,
    genre_class,
    discount
FROM
    DiscountedGenres
ORDER BY genre_class;
