-- 1. Customer behavior and perferences insights
--- Q1: Which genres of movies are most popular among the customers? 

WITH table1 AS (
	SELECT 
		c.name , 
		r.rental_id
	FROM	category c 
	JOIN film_category fc ON c.category_id = fc.category_id
	JOIN inventory i  ON fc.film_id = i.film_id
	JOIN rental r ON i.inventory_id = r.inventory_id
	)
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
WITH table1 AS	(
	SELECT 
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
	DATE_TRUNC('Month', rental_date) AS rental_month,
	COUNT(*) AS total_rentals
FROM rental
GROUP BY rental_month
   
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
ORDER BY total_rentals DESC;

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

-- Q2: What are the Top 5 country based on total rental?
WITH CountryTable AS (
	SELECT 
	DISTINCT cy.country,COUNT(r.customer_id) AS total_customers
	FROM 
		customer c
	JOIN address a ON c.address_id = a.address_id
	JOIN city ci ON a.city_id = ci.city_id 
	JOIN country cy ON ci.country_id = cy.country_id 
	JOIN rental r ON c.customer_id = r.customer_id 
	GROUP BY cy.country
	)
SELECT 
	country,
	total_customers
FROM
	CountryTable
GROUP BY country, total_customers
ORDER BY total_customers DESC
LIMIT 5;

-- Q3: What are the Bottom 5 country based on total rental?
WITH CountryTable AS (
	SELECT 
	DISTINCT cy.country,COUNT(r.customer_id) AS total_customers
	FROM 
		customer c
	JOIN address a ON c.address_id = a.address_id
	JOIN city ci ON a.city_id = ci.city_id 
	JOIN country cy ON ci.country_id = cy.country_id 
	JOIN rental r ON c.customer_id = r.customer_id 
	GROUP BY cy.country
	)
SELECT 
	country,
	total_customers
FROM
	CountryTable
GROUP BY country, total_customers
ORDER BY total_customers ASC 
LIMIT 5;


-- 4. Movie Performance
--- Q1: What are the TOP 3 genres ranked by gross revenue?
SELECT 
	c.name,
	SUM(p.amount) AS gross_revenue
FROM category c 
JOIN film_category fc ON c.category_id = fc.category_id 
JOIN inventory i ON fc.film_id = i.film_id 
JOIN rental r ON i.inventory_id = r.inventory_id 
JOIN payment p ON r.rental_id = p.rental_id 
GROUP BY c."name" 
ORDER BY gross_revenue DESC 
LIMIT 3 ;

--- Q2: How much the gross revenue for sports movies in Juni-Agustus 2005? 
SELECT
  	TO_CHAR(rental_date,'Month')  AS rental_month,
  	TO_CHAR(rental_date, 'yyyy') AS rental_year,
	SUM(payment.amount) AS gross_revenue
FROM 
	rental r
JOIN inventory i  ON r.inventory_id = i.inventory_id 
JOIN film_category fc ON i.film_id = fc.film_id 
JOIN category c ON fc.category_id = c.category_id 
JOIN payment ON r.rental_id = payment.rental_id
WHERE c."name" = 'Sports'
    AND rental_date BETWEEN '2005-06-01' AND '2005-08-31'
GROUP BY rental_month,rental_year
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
    dg.category_id,
    dg.category_name,
    dg.genre_class,
    SUM(r.rental_id) AS total_rental,
    dg.discount
FROM
    DiscountedGenres AS dg
JOIN film_category fc ON dg.category_id = fc.category_id
JOIN inventory i ON fc.film_id = i.film_id 
JOIN rental r ON i.inventory_id = r.inventory_id 
GROUP BY dg.category_id, dg.category_name, dg.genre_class, dg.discount
ORDER BY total_rental;

WITH RankedGenres AS (
    SELECT
        c.category_id,
        COUNT(r.rental_id) AS total_rental,
        NTILE(3) OVER (ORDER BY COALESCE(COUNT(r.rental_id), 0) DESC) AS genre_rank
    FROM
        category c
    LEFT JOIN film_category fc ON c.category_id = fc.category_id
    LEFT JOIN inventory i ON fc.film_id = i.film_id
    LEFT JOIN rental r ON i.inventory_id = r.inventory_id
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
    JOIN category c ON rg.category_id = c.category_id
)
SELECT
    dg.category_id,
    dg.category_name,
    dg.genre_class,
    SUM(r.rental_id) AS total_rental,
    dg.discount
FROM
    DiscountedGenres AS dg
JOIN film_category fc ON dg.category_id = fc.category_id
JOIN inventory i ON fc.film_id = i.film_id 
JOIN rental r ON i.inventory_id = r.inventory_id 
GROUP BY dg.category_id, dg.category_name, dg.genre_class, dg.discount
ORDER BY total_rental;

-- 6. STORE AND STAFF PERFORMANCE
--- Q1: Provide store performance (including total rental and gross revenue).
SELECT 
	s.store_id,  
	CONCAT(sf.first_name, ' ', sf.last_name) AS staff_name,
	COUNT(r.rental_id) AS total_rental,
	SUM(p.amount) AS gross_revenue 
FROM store s 
JOIN staff sf ON s.store_id = sf.store_id
JOIN customer c ON s.store_id = c.store_id 
JOIN rental r ON c.customer_id = c.customer_id 
JOIN payment p ON r.rental_id = p.rental_id 
GROUP BY s.store_id, sf.staff_id 
ORDER BY s.store_id;


--- Q2: What is the incentive amount for each staff member?
WITH staff_performance AS (
	SELECT	
		s.staff_id,
		CONCAT(s.first_name, ' ', s.last_name) AS staff_name,
		COUNT(r.rental_id) AS total_rental,
		SUM(p.amount) AS gross_revenue 
	FROM staff s 
	JOIN rental r ON s.staff_id = r.rental_id 
	JOIN payment p ON s.staff_id = p.staff_id 
	GROUP BY s.staff_id 
	ORDER BY s.staff_id
	),
 incentive_calculation AS (
 	SELECT 
		staff_name,
		ROUND(SUM(gross_revenue*0.05), 2) AS incentive_bonus
	FROM staff_performance 
	GROUP BY staff_name
	)
SELECT 
	incentive_calculation.staff_name AS staff_name,
	incentive_bonus 
FROM incentive_calculation
GROUP BY staff_name, incentive_bonus;


