class QuizGameFlow < Conduit::Flow
  QUESTIONS = [
    {
      question: "What is the capital of Kenya?",
      options: ["1. Nairobi", "2. Mombasa", "3. Kisumu", "4. Nakuru"],
      answer: "1"
    },
    {
      question: "Which year did Kenya gain independence?",
      options: ["1. 1960", "2. 1963", "3. 1965", "4. 1970"],
      answer: "2"
    },
    {
      question: "What is Kenya's highest mountain?",
      options: ["1. Mt. Elgon", "2. Mt. Longonot", "3. Mt. Kenya", "4. Mt. Kilimanjaro"],
      answer: "3"
    }
  ]

  initial_state :welcome

  state :welcome do
    display <<~TEXT
      Welcome to Quiz Master!
      Test your knowledge and win prizes.

      1. Start Quiz
      2. View High Scores
      3. Exit
    TEXT

    on "1" do |_, session|
      session.data[:score] = 0
      session.data[:question_index] = 0
      session.navigate_to(:question)
    end

    on "2", to: :high_scores
    on "3" do
      Conduit::Response.new(text: "Thanks for playing Quiz Master!", action: :end)
    end
  end

  state :question do
    display do |session|
      q_index = session.data[:question_index]
      question = QUESTIONS[q_index]

      text = "Question #{q_index + 1} of #{QUESTIONS.length}\n\n"
      text += "#{question[:question]}\n\n"
      text += question[:options].join("\n")
      text
    end

    on_any do |input, session|
      q_index = session.data[:question_index]
      question = QUESTIONS[q_index]

      if input == question[:answer]
        session.data[:score] += 1
        session.data[:last_correct] = true
      else
        session.data[:last_correct] = false
      end

      session.data[:question_index] += 1

      if session.data[:question_index] >= QUESTIONS.length
        session.navigate_to(:game_over)
      else
        session.navigate_to(:question_feedback)
      end
    end
  end

  state :question_feedback do
    display do |session|
      if session.data[:last_correct]
        "✓ Correct! Well done!\n\n1. Next question"
      else
        "✗ Wrong answer. Better luck next time!\n\n1. Next question"
      end
    end

    on "1", to: :question
  end

  state :game_over do
    display do |session|
      score = session.data[:score]
      total = QUESTIONS.length
      percentage = (score.to_f / total * 100).round

      text = "Quiz Complete!\n\n"
      text += "Your score: #{score}/#{total} (#{percentage}%)\n\n"

      text += case percentage
      when 90..100 then "🏆 Excellent! You're a champion!"
      when 70..89 then "🌟 Great job! Well done!"
      when 50..69 then "👍 Good effort! Keep learning!"
      else "📚 Keep practicing! You'll do better next time!"
      end

      text += "\n\n1. Play again\n2. Main menu"
      text
    end

    on "1" do |_, session|
      session.data[:score] = 0
      session.data[:question_index] = 0
      session.navigate_to(:question)
    end

    on "2", to: :welcome
  end

  state :high_scores do
    display <<~TEXT
      🏆 HIGH SCORES 🏆

      1. John K. - 3/3 (100)
      2. Mary N. - 2/3 (67)
      3. Peter M. - 2/3 (67)

      0. Back
    TEXT
  end
end
