class Exercise {
  final String id;
  final String name;
  final String muscle;
  final int sets;
  final String reps;
  final int load;
  final int rest;

  const Exercise({
    required this.id,
    required this.name,
    required this.muscle,
    required this.sets,
    required this.reps,
    required this.load,
    required this.rest,
  });
}

class Workout {
  final String id;
  final String name;
  final String label;
  final String dayOfWeek;
  final String emoji;
  final int duration;
  final List<Exercise> exercises;

  const Workout({
    required this.id,
    required this.name,
    required this.label,
    required this.dayOfWeek,
    required this.emoji,
    required this.duration,
    required this.exercises,
  });
}

class Meal {
  final String id;
  final String name;
  final String time;
  final String emoji;
  final int calories;
  final int protein;
  final int carbs;
  final int fat;
  final List<MealFood> foods;

  const Meal({
    required this.id,
    required this.name,
    required this.time,
    required this.emoji,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.foods,
  });
}

class MealFood {
  final String name;
  final String amount;
  final int calories;

  const MealFood({
    required this.name,
    required this.amount,
    required this.calories,
  });
}

class GoalItem {
  final String id;
  final String title;
  final double current;
  final double target;
  final String unit;
  final String deadline;
  final bool completed;

  const GoalItem({
    required this.id,
    required this.title,
    required this.current,
    required this.target,
    required this.unit,
    required this.deadline,
    this.completed = false,
  });

  double get progress => current / target;
}

class Badge {
  final String id;
  final String title;
  final String emoji;
  final bool unlocked;

  const Badge({
    required this.id,
    required this.title,
    required this.emoji,
    required this.unlocked,
  });
}

class AppNotification {
  final String id;
  final String title;
  final String message;
  final String time;
  final String emoji;
  final bool unread;

  const AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.time,
    required this.emoji,
    required this.unread,
  });
}

// ===== DADOS DO USUÁRIO =====
const userName = 'Lucas';
const userFullName = 'Lucas Oliveira';
const userEmail = 'lucas@email.com';
const userWeight = 78.0;
const userHeight = 175.0;
const userAge = 27;
const userIMC = 25.5;
const userIMCLabel = 'Sobrepeso';
const userTMB = 1820;
const userTDEE = 2821;
const weeklyWorkouts = 3;

// ===== TREINOS =====
const workouts = [
  Workout(
    id: 'a',
    name: 'Treino A',
    label: 'Peito + Tríceps',
    dayOfWeek: 'Segunda',
    emoji: '💪',
    duration: 55,
    exercises: [
      Exercise(id: 'a1', name: 'Supino Reto', muscle: 'Peito', sets: 4, reps: '8-12', load: 60, rest: 90),
      Exercise(id: 'a2', name: 'Supino Inclinado', muscle: 'Peito', sets: 3, reps: '10-12', load: 50, rest: 90),
      Exercise(id: 'a3', name: 'Crucifixo', muscle: 'Peito', sets: 3, reps: '12-15', load: 16, rest: 60),
      Exercise(id: 'a4', name: 'Tríceps Corda', muscle: 'Tríceps', sets: 3, reps: '12-15', load: 20, rest: 60),
      Exercise(id: 'a5', name: 'Tríceps Testa', muscle: 'Tríceps', sets: 3, reps: '10-12', load: 18, rest: 60),
    ],
  ),
  Workout(
    id: 'b',
    name: 'Treino B',
    label: 'Costas + Bíceps',
    dayOfWeek: 'Terça',
    emoji: '🔙',
    duration: 50,
    exercises: [
      Exercise(id: 'b1', name: 'Puxada Frontal', muscle: 'Costas', sets: 4, reps: '8-12', load: 55, rest: 90),
      Exercise(id: 'b2', name: 'Remada Curvada', muscle: 'Costas', sets: 3, reps: '10-12', load: 60, rest: 90),
      Exercise(id: 'b3', name: 'Remada Unilateral', muscle: 'Costas', sets: 3, reps: '12', load: 24, rest: 60),
      Exercise(id: 'b4', name: 'Rosca Direta', muscle: 'Bíceps', sets: 3, reps: '10-12', load: 30, rest: 60),
      Exercise(id: 'b5', name: 'Rosca Martelo', muscle: 'Bíceps', sets: 3, reps: '12', load: 14, rest: 60),
    ],
  ),
  Workout(
    id: 'c',
    name: 'Treino C',
    label: 'Pernas + Ombros',
    dayOfWeek: 'Quarta',
    emoji: '🦵',
    duration: 65,
    exercises: [
      Exercise(id: 'c1', name: 'Agachamento', muscle: 'Quadríceps', sets: 4, reps: '8-12', load: 80, rest: 120),
      Exercise(id: 'c2', name: 'Leg Press', muscle: 'Quadríceps', sets: 3, reps: '12-15', load: 120, rest: 90),
      Exercise(id: 'c3', name: 'Cadeira Extensora', muscle: 'Quadríceps', sets: 3, reps: '15', load: 50, rest: 60),
      Exercise(id: 'c4', name: 'Desenvolvimento', muscle: 'Ombros', sets: 3, reps: '10-12', load: 30, rest: 60),
      Exercise(id: 'c5', name: 'Elevação Lateral', muscle: 'Ombros', sets: 3, reps: '15', load: 10, rest: 45),
    ],
  ),
];

// ===== NUTRIÇÃO =====
const caloriesCurrent = 1940;
const caloriesTarget = 2200;
const proteinCurrent = 140;
const proteinTarget = 160;
const carbsCurrent = 200;
const carbsTarget = 250;
const fatCurrent = 55;
const fatTarget = 65;

const meals = [
  Meal(
    id: 'm1',
    name: 'Café da Manhã',
    time: '07:00',
    emoji: '☕',
    calories: 450,
    protein: 30,
    carbs: 55,
    fat: 12,
    foods: [
      MealFood(name: 'Ovos mexidos (3)', amount: '150g', calories: 210),
      MealFood(name: 'Pão integral', amount: '2 fatias', calories: 140),
      MealFood(name: 'Banana', amount: '1 unid', calories: 100),
    ],
  ),
  Meal(
    id: 'm2',
    name: 'Almoço',
    time: '12:30',
    emoji: '🍽️',
    calories: 750,
    protein: 55,
    carbs: 80,
    fat: 20,
    foods: [
      MealFood(name: 'Frango grelhado', amount: '200g', calories: 330),
      MealFood(name: 'Arroz integral', amount: '150g', calories: 250),
      MealFood(name: 'Brócolis', amount: '100g', calories: 55),
      MealFood(name: 'Azeite', amount: '1 colher', calories: 115),
    ],
  ),
  Meal(
    id: 'm3',
    name: 'Lanche da Tarde',
    time: '16:00',
    emoji: '🥤',
    calories: 320,
    protein: 30,
    carbs: 35,
    fat: 8,
    foods: [
      MealFood(name: 'Whey protein', amount: '30g', calories: 120),
      MealFood(name: 'Batata-doce', amount: '100g', calories: 120),
      MealFood(name: 'Amendoim', amount: '20g', calories: 80),
    ],
  ),
  Meal(
    id: 'm4',
    name: 'Jantar',
    time: '20:00',
    emoji: '🌙',
    calories: 420,
    protein: 35,
    carbs: 30,
    fat: 15,
    foods: [
      MealFood(name: 'Tilápia', amount: '180g', calories: 200),
      MealFood(name: 'Batata-doce', amount: '150g', calories: 130),
      MealFood(name: 'Salada verde', amount: '100g', calories: 90),
    ],
  ),
];

// ===== METAS =====
const goals = [
  GoalItem(
    id: 'g1',
    title: 'Perder 5kg de gordura',
    current: 4.0,
    target: 5.0,
    unit: 'kg',
    deadline: '31/05/2026',
  ),
  GoalItem(
    id: 'g2',
    title: 'Supino 100kg',
    current: 70.0,
    target: 100.0,
    unit: 'kg',
    deadline: '30/11/2026',
  ),
  GoalItem(
    id: 'g3',
    title: 'Comer 2000 kcal/dia',
    current: 7.0,
    target: 7.0,
    unit: 'dias',
    deadline: '07/05/2026',
    completed: true,
  ),
];

// ===== CONQUISTAS =====
const badges = [
  Badge(id: 'b1', title: 'Primeiro Treino', emoji: '🥇', unlocked: true),
  Badge(id: 'b2', title: 'Semana Completa', emoji: '🔥', unlocked: true),
  Badge(id: 'b3', title: 'PR de Supino', emoji: '🏆', unlocked: true),
  Badge(id: 'b4', title: 'Maratonista', emoji: '🎯', unlocked: true),
  Badge(id: 'b5', title: '30 Treinos', emoji: '💎', unlocked: false),
  Badge(id: 'b6', title: 'Mestre da Nutrição', emoji: '🥗', unlocked: false),
];

// ===== NOTIFICAÇÕES =====
const notifications = [
  AppNotification(
    id: 'n1',
    title: 'Hora do Treino!',
    message: 'Seu Treino A está programado para hoje',
    time: '08:00',
    emoji: '🏋️',
    unread: true,
  ),
  AppNotification(
    id: 'n2',
    title: 'Lanche da tarde',
    message: 'Lembre-se de tomar o whey protein',
    time: '16:00',
    emoji: '🍎',
    unread: true,
  ),
  AppNotification(
    id: 'n3',
    title: 'Nova conquista! 🏆',
    message: "Você desbloqueou o badge 'PR de Supino'",
    time: 'Ontem',
    emoji: '🏆',
    unread: false,
  ),
  AppNotification(
    id: 'n4',
    title: 'Ficha atualizada',
    message: 'Seu personal atualizou o Treino B',
    time: '12/04',
    emoji: '⚙️',
    unread: false,
  ),
];

// ===== DADOS DO PERSONAL =====
const trainerName = 'Roberto';
const trainerFullName = 'Roberto Silva';
const trainerEmail = 'roberto@email.com';
const trainerPhone = '(11) 99999-0000';
const trainerCREF = '012345-G/SP';

// ===== ALUNOS DO PERSONAL =====
class Student {
  final String id;
  final String name;
  final String goal;
  final String lastSession;
  final double progress;

  const Student({
    required this.id,
    required this.name,
    required this.goal,
    required this.lastSession,
    required this.progress,
  });
}

const students = [
  Student(
    id: 's1',
    name: 'Lucas Oliveira',
    goal: 'Ganhar Massa',
    lastSession: 'Hoje',
    progress: 75,
  ),
  Student(
    id: 's2',
    name: 'Ana Costa',
    goal: 'Emagrecer',
    lastSession: 'Ontem',
    progress: 60,
  ),
  Student(
    id: 's3',
    name: 'Pedro Santos',
    goal: 'Resistência',
    lastSession: '3 dias atrás',
    progress: 45,
  ),
  Student(
    id: 's4',
    name: 'Mariana Lima',
    goal: 'Manter Peso',
    lastSession: 'Hoje',
    progress: 80,
  ),
];