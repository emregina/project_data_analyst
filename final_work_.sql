-- Проектная работа по модулю “SQL и получение данных”
-- Приложение №2

-- Задание №1
-- В каких городах больше одного аэропорта?
select city
from airports
group by city
having count(airport_code) > 1
-- логика: сгруппировала данные по городам и сделала фильтр показывать те, у которых счетчик больше 1

-- Задание №2 
-- В каких аэропортах есть рейсы, выполняемые самолетом с максимальной дальностью перелета?
select distinct a2.airport_name 
from flights f
inner join airports a2 on a2.airport_code = f.departure_airport 
inner join aircrafts a on a.aircraft_code = f.aircraft_code 
where a.range = (select max(range)
                 from aircrafts)
-- логика: к таблице рейсов присоединила нужные таблицы, отфильтровала записи через подзапрос, 
-- где нашла макс. дальность перелета, вывела уникальные наименования аэропортов

-- Задание №3 
-- Вывести 10 рейсов с максимальным временем задержки вылета
select flight_id, flight_no, scheduled_departure, actual_departure, 
       actual_departure - scheduled_departure as "Время задержки вылета"
from flights f 
where actual_departure is not null
order by actual_departure - scheduled_departure desc
limit 10
-- отфильтровала данные, чтобы не попали самолеты еще не вылетевшие, после отсортировала по разнице между 
-- временем вылета запланированным и фактическим, поставила лимит на вывод 

-- Задание №4
-- Были ли брони, по которым не были получены посадочные талоны?
select b.book_ref, b.book_date, t.ticket_no, t.passenger_name, bp.boarding_no 
from bookings b 
inner join tickets t on t.book_ref = b.book_ref 
left join boarding_passes bp on bp.ticket_no = t.ticket_no 
where bp.boarding_no is null
-- присоединила нужные таблицы и поставила фильтр где вывела те талоны где значение пустое, но оно есть.

-- Задание №5 
-- Найдите количество свободных мест для каждого рейса, их % отношение к общему количеству мест в самолете.
-- Добавьте столбец с накопительным итогом - 
-- суммарное накопление количества вывезенных пассажиров из каждого аэропорта на каждый день. 
-- Т.е. в этом столбце должна отражаться накопительная сумма - сколько человек 
-- уже вылетело из данного аэропорта на этом или более ранних рейсах в течении дня.
with cte_seats as (
          select flight_id, count(ticket_no) -- купленые билеты
          from ticket_flights 
          group by flight_id 
          order by flight_id)
select f.flight_id, f.departure_airport, s1.count - cte_seats.count as "свободные места", 
       round((s1.count - cte_seats.count)::numeric * 100 / s1.count::numeric, 2) as "% отношение к общему кол-ву",
       f.actual_departure, 
       case 
           when f.actual_departure is not null 
           then sum(cte_seats.count) over (partition by f.departure_airport, date_part('day', f.actual_departure) 
                order by f.actual_departure)
       end as "Вывезенные пассажиры"
from cte_seats
inner join flights f on f.flight_id = cte_seats.flight_id
inner join (select aircraft_code, count(seat_no)  -- общее кол-во мест в самолете
            from seats 
            group by aircraft_code) as s1 on s1.aircraft_code = f.aircraft_code
-- логика: создала cte в котором храниться сколько билетов было куплено, обогатила полученные данные: 
-- присоединила таблицу рейсов и общее количество мест в самолете, найденные через подзапрос, затем вывела
-- нужные столбцы и арифметически посчитала свободные места и их % отношение.
-- через оператора case у фактически улетевших самолетов посчитала накопительный итог по вывезенным пассажирам
-- по каждому аэропорту и на каждый день

-- Задание №6
-- Найдите процентное соотношение перелетов по типам самолетов от общего количества.
select aircraft_code, round(count(flight_id)::numeric * 100 / 
       (select count(flight_id)::numeric from flights f2), 2) 
from flights f 
group by aircraft_code 
-- логика: я сгруппировала данные по типам самолетов и посчитала количество перелетов
-- разделила на подзапрос, где посчитала общее кол-во перелетов, из больших целочисленных значений
-- привела к числу с плавающей точкой, затем округлила полученный результат, до 2х знаков после запятой 

-- Задание №7 
-- Между какими городами нет прямых рейсов? 
create materialized view not_flights as
    select a1.city as "Пункт 1", a2.city as "Пункт 2"
    from airports a1, airports a2 -- всевозможные пары городов
    where a1.city != a2.city and a1.city > a2.city
    except
    select a1.city, a2.city -- города между которыми производятся рейсы
    from flights f
    inner join airports a1 on a1.airport_code = f.departure_airport 
    inner join airports a2 on a2.airport_code = f.arrival_airport  

select * 
from not_flights 
-- логика: сначала я нашла все возможные комбинации городов за исключение повторяющихся А=А и В=А,А=В;
-- затем я нашла города между, которыми производятся рейсы, используя оператор except я оставила только те пары,
-- рейсов между которыми нет  

-- Задание №8 
-- Вычислите расстояние между аэропортами, связанными прямыми рейсами, 
-- сравните с допустимой максимальной дальностью перелетов  в самолетах, обслуживающих эти рейсы *
select distinct f.departure_airport, a1.city, f.arrival_airport, a2.city,
            (acos(sind(a1.latitude) * sind(a2.latitude) 
            + cosd(a1.latitude) * cosd(a2.latitude) 
            * cosd((a1.longitude - a2.longitude)))) * 6371 as "расстояние между пунктами",
            a.range as "максимальная дальность перелетов",
            case
                when (acos(sind(a1.latitude) * sind(a2.latitude) 
                     + cosd(a1.latitude) * cosd(a2.latitude) 
                     * cosd((a1.longitude - a2.longitude)))) * 6371 < a."range" then 'Yes'
                else 'No'
            end as "check"
from flights f 
inner join airports a1 on a1.airport_code = f.departure_airport 
inner join airports a2 on a2.airport_code = f.arrival_airport
inner join aircrafts a on f.aircraft_code = a.aircraft_code  
-- логика: сначала я присоединила к таблице рейсов, таблицу аэропорты, чтобы вывести уникальные пары 
-- и узнать широту и долготу местонахождения аэропорта, затем по формуле я нашла расстояние между тА и тБ,
-- присоединила таблицу самолетов для получения макс дальности перелета, через оператор case сравнила 
-- эти две сущности и вывела да/нет, чтобы увидеть долетит самолет или нет