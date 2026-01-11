class Transport:
    def move(self):
        print("Транспорт движется")

class Car(Transport):
    def move(self):
        print("Автомобиль едет")

    def fuel(self):
        print("Автомобиль заправляется")

t = Transport()
c = Car()

t.move()
c.move()
c.fuel()
