-- ������� �1
-- � ����� ������� ������ ������ ���������?
select city
from airports
group by city
having count(airport_code) > 1
-- ������: ������������� ������ �� ������� � ������� ������ ���������� ��, � ������� ������� ������ 1

-- ������� �2 
-- � ����� ���������� ���� �����, ����������� ��������� � ������������ ���������� ��������?
select distinct a2.airport_name 
from flights f
inner join airports a2 on a2.airport_code = f.departure_airport 
inner join aircrafts a on a.aircraft_code = f.aircraft_code 
where a.range = (select max(range)
                 from aircrafts)
-- ������: � ������� ������ ������������ ������ �������, ������������� ������ ����� ���������, 
-- ��� ����� ����. ��������� ��������, ������ ���������� ������������ ����������

-- ������� �3 
-- ������� 10 ������ � ������������ �������� �������� ������
select flight_id, flight_no, scheduled_departure, actual_departure, 
       actual_departure - scheduled_departure as "����� �������� ������"
from flights f 
where actual_departure is not null
order by actual_departure - scheduled_departure desc
limit 10
-- ������������� ������, ����� �� ������ �������� ��� �� ����������, ����� ������������� �� ������� ����� 
-- �������� ������ ��������������� � �����������, ��������� ����� �� ����� 

-- ������� �4
-- ���� �� �����, �� ������� �� ���� �������� ���������� ������?
select b.book_ref, b.book_date, t.ticket_no, t.passenger_name, bp.boarding_no 
from bookings b 
inner join tickets t on t.book_ref = b.book_ref 
left join boarding_passes bp on bp.ticket_no = t.ticket_no 
where bp.boarding_no is null
-- ������������ ������ ������� � ��������� ������ ��� ������ �� ������ ��� �������� ������, �� ��� ����.

-- ������� �5 
-- ������� ���������� ��������� ���� ��� ������� �����, �� % ��������� � ������ ���������� ���� � ��������.
-- �������� ������� � ������������� ������ - 
-- ��������� ���������� ���������� ���������� ���������� �� ������� ��������� �� ������ ����. 
-- �.�. � ���� ������� ������ ���������� ������������� ����� - ������� ������� 
-- ��� �������� �� ������� ��������� �� ���� ��� ����� ������ ������ � ������� ���.
with cte_seats as (
          select flight_id, count(ticket_no) -- �������� ������
          from ticket_flights 
          group by flight_id 
          order by flight_id)
select f.flight_id, f.departure_airport, s1.count - cte_seats.count as "��������� �����", 
       round((s1.count - cte_seats.count)::numeric * 100 / s1.count::numeric, 2) as "% ��������� � ������ ���-��",
       f.actual_departure, 
       case 
           when f.actual_departure is not null 
           then sum(cte_seats.count) over (partition by f.departure_airport, date_part('day', f.actual_departure) 
                order by f.actual_departure)
       end as "���������� ���������"
from cte_seats
inner join flights f on f.flight_id = cte_seats.flight_id
inner join (select aircraft_code, count(seat_no)  -- ����� ���-�� ���� � ��������
            from seats 
            group by aircraft_code) as s1 on s1.aircraft_code = f.aircraft_code
-- ������: ������� cte � ������� ��������� ������� ������� ���� �������, ��������� ���������� ������: 
-- ������������ ������� ������ � ����� ���������� ���� � ��������, ��������� ����� ���������, ����� ������
-- ������ ������� � ������������� ��������� ��������� ����� � �� % ���������.
-- ����� ��������� case � ���������� ��������� ��������� ��������� ������������� ���� �� ���������� ����������
-- �� ������� ��������� � �� ������ ����

-- ������� �6
-- ������� ���������� ����������� ��������� �� ����� ��������� �� ������ ����������.
select aircraft_code, round(count(flight_id)::numeric * 100 / 
       (select count(flight_id)::numeric from flights f2), 2) 
from flights f 
group by aircraft_code 
-- ������: � ������������� ������ �� ����� ��������� � ��������� ���������� ���������
-- ��������� �� ���������, ��� ��������� ����� ���-�� ���������, �� ������� ������������� ��������
-- ������� � ����� � ��������� ������, ����� ��������� ���������� ���������, �� 2� ������ ����� ������� 

-- ������� �7 
-- ����� ������ �������� ��� ������ ������? 
create materialized view not_flights as
    select a1.city as "����� 1", a2.city as "����� 2"
    from airports a1, airports a2 -- ������������ ���� �������
    where a1.city != a2.city and a1.city > a2.city
    except
    select a1.city, a2.city -- ������ ����� �������� ������������ �����
    from flights f
    inner join airports a1 on a1.airport_code = f.departure_airport 
    inner join airports a2 on a2.airport_code = f.arrival_airport  

select * 
from not_flights 
-- ������: ������� � ����� ��� ��������� ���������� ������� �� ���������� ������������� �=� � �=�,�=�;
-- ����� � ����� ������ �����, �������� ������������ �����, ��������� �������� except � �������� ������ �� ����,
-- ������ ����� �������� ���  

-- ������� �8 
-- ��������� ���������� ����� �����������, ���������� ������� �������, 
-- �������� � ���������� ������������ ���������� ���������  � ���������, ������������� ��� ����� *
select distinct f.departure_airport, a1.city, f.arrival_airport, a2.city,
            (acos(sind(a1.latitude) * sind(a2.latitude) 
            + cosd(a1.latitude) * cosd(a2.latitude) 
            * cosd((a1.longitude - a2.longitude)))) * 6371 as "���������� ����� ��������",
            a.range as "������������ ��������� ���������",
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
-- ������: ������� � ������������ � ������� ������, ������� ���������, ����� ������� ���������� ���� 
-- � ������ ������ � ������� ��������������� ���������, ����� �� ������� � ����� ���������� ����� �� � ��,
-- ������������ ������� ��������� ��� ��������� ���� ��������� ��������, ����� �������� case �������� 
-- ��� ��� �������� � ������ ��/���, ����� ������� ������� ������� ��� ���